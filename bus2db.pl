package bus2db;
=pod

=head1 NAME

 bus2db.pl
 
=head1 SYNOPSIS

 A bus-aware plugin that passes messages from an Openkore instance 
 to a standalone bus client (bus2db-client.pl), which updates the
 koreInventory database.

=head1 DESCRIPTION

 This Openkore plugin communicates with a separate, standalone bus client
 that does the actual database queries/updates.
 
 This architecture allows for multiple Openkore instances to update the
 database, without concern about queuing or slowdowns for higher volumes
 of querying.  Also, the standalone script being the sole gateway to the 
 database allows it to act as the gatekeeper, authenticating clients,
 authorizing those allowed to interact, and validating messages sent.

=head1 IMPLEMENTATION NOTES:

  The hash of hashes listed below... should probably be pulled out into
 a module in future revisions, to contain all it's behavior and simplify
 this unit.

=head2 Data Structures:

  %busClients - hash of hashes, holding info about each of the connected 
  bus clients. 
  Key			Value
  BusID	=>		{ clientInfo hash holding various values }
  (^ as seen in the LIST_CLIENTS message)
  
  "%clientInfo" - a hash stored within %busClients, with the following
  entries:
  Key				Value
  ---				-----
  ServerIdx 	=>	(Positive Integer)	# must match ServerIdx in Accounts
  AccountName	=>	(String)

  CharIdx		=>	(Positive Integer, unique)
  CharName		=>	(String)
  
-- unique pair
- ServerIdx	integer
- AccountName
--
- CharIdx	integer (unique)
- CharName
- InZone	boolean
- Authenticated	boolean (for security purposes)


From server:
AccountNumber	(ID in Account, match by AccountID in Characters, and AccountName from client)
CharacterNumber	(ID in Characters)

Match these in Characters table, by name from client.

=head2 Requirements:

Openkore, revision r8965 or later (this plugin requires the "zeny_change"
callback hook to exist, or it'll never report a thing that will update your
koreInventory Database.

=cut

#========================================================================
#  Modifications:
#  by ChrstphrR
# 
#  Intent: change the behaviour of this plugin, so that it implements the
# suggestion of EternalHarvest in the source thread on the openkore forums:
# 
# "Wouldn't it be nice to have different commands for invoking commands and for
# messaging mode, so they can be used simultaneously and without configuration?"
#
# 2012/09/03rd: Planning stage:
# - added a BUS_MESSAGE constant to mimic BUS_COMMAND, this will be used for
# sending the messages only, instead of only relying on the "MESSENGER_MODE"
# check to determine that.
#
# - the constants as used are too simple - these should be (private?) variables,
# that are initialized using defaults shown OR via well documented config.txt
# values for this plugin.  The rigidity here is what makes it difficult to 
# implement simultaneous bus commands/messages both...
#
#========================================================================

use strict;
#use warnings;
#no warnings 'redefine';

use Plugins;
use Log qw( warning message error );
use Globals;

## While testing, we'll be using this to help debug... :P
use Data::Dumper;
use Bus::Client;

#Constants, used in Bus::Client
# State constants.
use constant {
	NOT_CONNECTED	=> 1,
	STARTING_SERVER	=> 2,
	HANDSHAKING		=> 3,
	CONNECTED		=> 4
};


use constant {
	VERSION => '0.1.0.0' # Alpha
};

use constant {
	PLUGIN			=> 'bus2db',
	# Custom bus messages to talk to bus2db.pl plugin:
	# BMC_*
	BMC_MESSAGE		=> 'BROADCAST_MSG',
	BMC_REGISTER	=> 'B2DB_REGISTER', # sent by db-client to plugins
	BMC_REGISTER_ME	=> 'B2DB_REGISTER_ME', # reply to above from plugin.
	# Custom messages that should interact with the database:
	BMC_ZENY		=> 'B2DB_ZENY',
	# Standard bus messages
	# BM_*
	BM_LISTCLIENTS	=> "LIST_CLIENTS",

	# command line constants
	# CMD_*
	CMD_MESSAGE		=> "bmsg",
	CMD_LISTCLIENTS	=> "lc",

	#msglevel constants (used in sub msg)
	MLVL_NONE		=> 0,
	MLVL_MSG		=> 1,
	MLVL_WARNING	=> 2,
	MLVL_ERROR		=> 3 
};

# Plugin setup: Register Plugin, commands, hooks used
Plugins::register(PLUGIN, "receive/send commands (and messages) via BUS system", \&unload, \&reload);

my $myCmds = Commands::register(
	[
		CMD_MESSAGE,
		"use ".CMD_MESSAGE." <all|player name|map name> <message here>",
		\&sendBusMessage
	],
	[
		CMD_LISTCLIENTS,
		"use ".CMD_LISTCLIENTS,
		\&sendListClients
	]
);

# separate hook/var for this, because we tend to alter it
my $networkHook = Plugins::addHook('Network::stateChanged',\&checkNetworkState);
my $hooks = Plugins::addHooks(
	['zeny_change',\&zenyChange] #this hook implemented in Openkore r8965
);
##

my $bus_message_received;
my $bus2db_busID;

## Send a normal bus message instead of a command
# 
sub sendBusMessage {
	my (undef, $cmm) = @_;
	$cmm =~ m/^"(.*)" (.*)$/;
	$cmm =~ m/^(\w+) (.*)$/ unless ($1);
	unless ($1 && $2) {
		msg("Command \"".CMD_MESSAGE."\" failed, please use ".CMD_MESSAGE." <all|player name|map name> <command>.", 3);
		return;
	}
	if ($char && $bus->getState == CONNECTED) {
		my %args;
		$args{player} = $1;
		$args{msg} = $2;
		$args{FromName} = $char->name; # Hey, let's tell them our name?
		$bus->send(BMC_MESSAGE, \%args);
	}

	if (
		($1 eq $char->name) || 
		$1 eq "all" ||
		($field) && ($1 eq $field->name)
	) {
		Plugins::callHook('bus_received', {message => $2});
		msg("bmsg: ".$2);
	}
}#sub sendBusMessage


## zeny_change callback :
# args: 
#	zeny	amt of zeny player has after
#	change	change in zeny - pos or negative.
#
sub zenyChange {
	if (!$char) {
		msg("Early Exit zenyChange.1");
		return;
	}
	if (!$bus2db_busID) {
		msg("Early Exit zenyChange.2");
		return;
	}

	my ($msgID, $args) = @_; # $msgID = 'zeny_change' the callback tag
	#$args refers to the hash stated above. Extract what we need:
	my $Zeny = $args->{zeny};
	my $Change = $args->{change};

	if (abs($Change) > 0) { #if there was a change (don't care which!)
		#send a bus packet to bus2db-client, please...
		msg("sending zeny message to bus2db...");
		$bus->send(
			BMC_ZENY,
			{
				'TO'	=> $bus2db_busID, #This is not seen by the other client, server removes it.
				'zeny' => $Zeny,
				'change' => $Change
			}
		);
	#account name
	#message T("AccountName: $config{'username'} \n"), "info";

	#account ID
	#message T("AccountID: $char->{'nameID'} *\n"), "info";
	}

	## Test phase: ensure this routine receives the zeny_change callback calls...
	## Later, once this is ensured, then we'll send a message over the bus to bus2db-client,
	## where it will update the database.
=pod
	if ($Change > 0) {
		msg("You gained $Change to have $Zeny");
	} elsif ($Change < 0) {
		msg('You lost '. abs($Change) ." to have $Zeny");
	} else {
		#Will it trigger with no zeny change? 
		#Maybe an initial packet set on map load?
		# - when interacting with npc - seems to double send, in fact...
		# maybe we should ignore a zero change to prevent unnecessary messages?
		msg("You have $Zeny");
	}
=cut
}; # zenyChange


## Send request to bus server to list clients connected.
#
# Borrowed idea/command from /src/test/bus-clients-test.pl
# 
sub sendListClients {
	my @args = @_;
	if ($bus->getState == CONNECTED) {
		if (@_ > 1) {
			$bus->send(
				'LIST_CLIENTS',
				{ 'SEQ' => $_[1] }
			);
			msg("list clients->busServer: SEQ = $_[1]");
		} else {
			$bus->send('LIST_CLIENTS');
			msg('list clients->busServer:');
		}
	}
}#sub sendListClients


# handle plugin loaded manually
if ($::net) {
	if ($::net->getState() > NOT_CONNECTED) {
		$bus_message_received = $bus->onMessageReceived->add(undef, \&bus_message_received);
		if ($networkHook) {
			Plugins::delHooks($networkHook);
			undef $networkHook;
		}
	}
}

sub checkNetworkState {
	return if ($::net->getState() == NOT_CONNECTED);
	if (!$bus) {
		die("\n\n[".PLUGIN."] You MUST start BUS server and configure each bot to use it in order to use this plugin. Open and edit line bus 0 to bus 1 inside control/sys.txt \n\n", 3, 0);
	} elsif (!$bus_message_received) {
		$bus_message_received = $bus->onMessageReceived->add(undef, \&busMessageReceived);
		Plugins::delHook($networkHook);
		undef $networkHook;
	}
}


## Recieved a bus message of some sort, let's check and see if we're
# supposed to handle it or not!

# receives all bus messages -- note, this means even ones we aren't
# generating, that other bus clients DID.
sub busMessageReceived {
	my (undef, undef, $msg) = @_;
	return if (!$char);

	my $isBMsg = ($msg->{messageID} eq BMC_MESSAGE);
	my $isRego = ($msg->{messageID} eq BMC_REGISTER);
	my $isList = ($msg->{messageID} eq BM_LISTCLIENTS);

	return unless ($isBMsg || $isList || $isRego);

	my $msgTarget = $msg->{args}{player};
	if (
		($msgTarget eq $char->name) ||
		($msgTarget eq "all") ||
		($field && $msgTarget eq $field->name)
	) {
		Plugins::callHook('bus_received', {message => $msg->{args}{msg}});

		if ($isBMsg) {
			###print Dumper($msg);
			# $msg has this structure:
			# $msg {
			#	messageID => 'busMsg'
			#	args {
			#		'FROM' => '9',	#numeric ID assigned by the Bus?
			#		'FromName' => 'Joe', # Nickname passed by sender
			#		'msg' => 'Hello?',	# Actual message contents
			#		'player => 'all'	# This is the target of the msg
			#	}
			# }//$msg
			msg("[".$msg->{args}{FromName}."]->[".$msg->{args}{player}."]: ".$msg->{args}{msg});
		}
	} elsif ($isRego) {
		#send info so we can be registered to send DB info...
		msg("REGISTER received -- sending REGISTER ME!");
		$bus2db_busID = $msg->{args}{FROM};
		$bus->send(
			BMC_REGISTER_ME,
			{
				TO		=> $bus2db_busID, #privmsg to the bus2db client
				AName	=> $config{username},
				AID		=> $char->{nameID},
				CName	=> $char->{name},
				CIdx	=> $config{char}
			}
		);
	} elsif ($isList) { #LIST_CLIENTS message received from server.
		msg("------- Client list --------");
		###print Dumper($msg);
		# $msg has this structure:
		# $msg = {
		#	'messageID' => 'LIST_CLIENTS',
		#	'args' => {
		#		'IRY' => 1,
		#		'clientUserAgent0' => 'OpenKore',
		#		'clientUserAgent1' => 'OpenKore',
		#		'clientUserAgent2' => 'OpenKore',
		#		'clientUserAgent3' => 'OpenKore',
		#		'client0' => 41
		#		'client1' => 33,
		#		'client2' => 34,
		#		'client3' => 35,
		#		'count' => 4,
		#	}
		# };
		for (my $i = 0; $i < $msg->{args}{count}; $i++) {
			msg($msg->{args}{"client$i"} ." : ". $msg->{args}{"clientUserAgent$i"});
		}
		msg("----------------------------");
	} else {
		msg("-----------------------");
		msg("Message from bus server: $msg->{messageID}");
		if (ref($msg) eq 'HASH') {
			foreach my $key (keys %{$msg}) {
				msg("$key => $msg->{$key}");
			}
		} else {
			foreach my $entry (@{$msg}) {
				msg("$entry");
			}
		}
		msg("-----------------------");
	}
}


## sub msg(<message> [, <msglevel>[, <debug>]])
## Utility routine:
#   Sends a text message, where? Depends on the message level!
#
# Parameters:
# <message>  : The text string of the message sent.
# [msglevel] : Optional parameter
#	MLVL_NONE, MLVL_WARNING, null, or undefined:
#		display as a warning (unless SILENT constant is 1)
#	MLVL_MSG:
#		display as a normally to console (unless SILENT constant is 1)
#	MLVL_ERROR:
#		display as an error message to stderr
#
# Side effects:
#	SILENT constant: will suppress all but msglevel = 3, if set to 1
#	DEBUG constant: will suppress all messages from this routine,
#	unless <debug> is 1, and DEBUG != 0
#
##messages to console (or warnings, or errors... gosh it'd be nice if these msglevel things were documented, too..
sub msg {
	# SILENT constant support and sprintf.
	my ($msg, $msglevel, $debug) = @_;

	unless ($debug eq 1) {
		$msg = "[".PLUGIN."] ".$msg."\n";
		if (
			!defined $msglevel || $msglevel == "" ||
			$msglevel == MLVL_NONE ||
			$msglevel == MLVL_WARNING
		) {
			warning($msg);
		} elsif ($msglevel == MLVL_MSG) {
			message($msg);
		}
	}
	return 1;
}

# Plugin unload
sub unload {
	__unload("\n[".PLUGIN."] unloading.\n\n");
}

## Bug - after reloading, the plugin crashes kore when one of its commands
## is invoked.
#
# Plugin reload
sub reload {
	__unload("\n[".PLUGIN."] reloading.\n\n");
}

# Common bits for the unload/reload routines - they pass the message as the only argument.
sub __unload {
	if (@_ == 1) {
		message($_[0]);
	}

	Plugins::delHooks($hooks) if $hooks;
	undef $hooks;

	Commands::unregister($myCmds);
	undef $myCmds;

	if ($bus_message_received) {
		$bus->onMessageReceived->remove($bus_message_received);
		undef $bus_message_received;
	}
	undef $bus2db_busID;
}


1;

=pod

=head1 SUPPORT

No support is available, expressed, or implied.

=head1 AUTHOR

Copyright 2015, ChrstphrR.

=head1 LICENSE

 (Licensed under BSD 3-clause / BSD "New" see:
 http://opensource.org/licenses/BSD-3-Clause )

 Copyright (c) 2015, ChrstphrR
 All rights reserved.

  Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions
 are met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright 
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.

 - Neither the name of ChrstphrR nor the names of its contributors may
   be used to endorse or promote products derived from this software
   without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

=cut
