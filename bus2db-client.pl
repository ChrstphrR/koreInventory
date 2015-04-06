#!/usr/bin/env perl
#
# bus2db-client.pl
#

########################################################################
#
# Based on /src/test/bus-client-test.pl -- just moved to /src/
# and added daemon like run-once handling,
# added fuller commands and handlers for some of the messages seen,
# and, most importantly: properly acknowledged the HELLO message from
# the bus server, so that this client is fully Identified, and thus,
# will actually *receive* broadcast messages!
#
# It's a bit messy compared to most of Openkore's modules, so...
# TODO: Organize and refactor code so it's a bit easier to read and 
# comprehend.
#
########################################################################


use strict;
use warnings;

##for debugging - when thoroughly debugged, this can go away:
#use Data::Dumper;

use JSON; 
# piggybacking on the files that are in deps that rachel put in for
# ragnastats-beta -- we will use this to read a json file, instead of
# sending JSON data.


## Array <= getDataFromJSON(String <Filename>)
#
# 
# returns an array containing: $hostname, $username, $password
# if the file passed can be opened.
# 
# It is the caller's responsibility to check if these returned values
# are valid or not.
#
sub getDBsettingsFromJSON
{
	my $fileName = shift;

	my $jsonText = do {
		open(my $jsonFH, "<:encoding(UTF-8)", $fileName)
		or return;
		local $/;
		<$jsonFH>
	};
	my $json = JSON->new;
	my $data = $json->decode($jsonText);
	#$data holds JSON data - return host/user/password to caller.

	return ($data->{host}, $data->{user}, $data->{password} );
}


##
# File locking -- prevent more than one instance of this file from running.
#
#
##
use Proc::ProcessTable;
my $count = 0;
my $table = Proc::ProcessTable->new;
for my $process ( @{ $table->table } ) {
	next unless $process->{cmndline};
	if ($process->{cmndline} =~ /$0/) {
		$count++;
		if ($count > 1) {
			die "This script is already running:";
		}
	}
}
##


use FindBin qw($RealBin);
use lib "$RealBin";
use lib "$RealBin/deps";

use Globals qw($interface);

## 2015/02/19 CRW
## with just SimpleClient, this instance gets on the bus, BUT, is not
## identified, ergo, the openkore instances can't see it.
## This MAY be useful if you don't wish to interact with openkore 
## instances, but in most cases... that's exactly the reason why you
## *are* connected to the bus in the first place!
## 
use Bus::Client;
#use Bus::SimpleClient;

use Interface::Console;
use Utils qw(parseArgs);



my $port;
if ($ARGV[0]) {
	$port = $ARGV[0];
} else {
	#TODO: make this handle no parameters, look for host/port in
	#/tmp/OpenKore-Bus.info first... if not found, hey, there's no bus
	#loaded, then give an error.

	print STDERR "No server port specified.\n";
	exit 1;
}


##======================================================================
##
## Constants
##
##======================================================================

# Plugin related constants
use constant {
	USERAGENT            => 'bus2db',
	#Will we need to make this a list of authorized clients??
	AUTHORIZED_USERAGENT => 'OpenKore',
	CHARNAME             => 'bus2db'
};

# Bus message related constants.
use constant {
	# Custom bus messages to talk to bus2db.pl plugin:
	# BMC_*
	BMC_MESSAGE     => 'BROADCAST_MSG',
	BMC_REGISTER    => 'B2DB_REGISTER', # sent by db-client to plugins
	BMC_REGISTER_ME => 'B2DB_REGISTER_ME', # reply to above from plugin.
	# Custom messages that should interact with the database:
	BMC_ZENY        => 'B2DB_ZENY',

	# Custom message sub-hash constants:
		#when a LIST_CLIENTS has this SEQ value, we try to register 
		#the listed clients to interact with the database.
	BMC_LC_SEQ        => 'f00', 

	# Standard bus messages
	# BM_*
	BM_HELLO        => 'HELLO',
	BM_JOIN         => 'JOIN',
	BM_LEAVE        => 'LEAVE',
	BM_LISTCLIENTS  => 'LIST_CLIENTS'

};

# DB Query related constants:
use constant {
	UPDATE_ZENY	=> 'UPDATE Characters SET Zeny = ? WHERE ID = ?' #pass dbCID, zenyamt
};
##======================================================================


print "Connecting to server at port $port\n";
$interface = new Interface::Console;
my $ipc;
my $busID;


use DBI;
use DBD::mysql;

my $dbh; # database handle
my $sth; # SQL transaction handle

=pod
Data structure for storing character info, so it need not be re-passed:
(TODO - this should be... a class?)

hash %Characters
{
	<ConnectionNumber> => { InfoHash }

}

hash %InfoHash
{
#Internal data for this client:
	Authenticated => '1',
		#Is the connection authenticated?
#Data passed from the other client:
	AName	=> 'joeblow',
	AID		=> '12345678',
	CName	=> 'Joe is a thief', $char{name} value.
	CIdx	=> '1', #zero-based indexing 0..N-1 -- $config{char} value
#Data passed from the database, verified by the client's data.
	dbServer	=> '0',
		#Server account is based on, this is from the DB
		#use the AName and AID to determine this.
	dbAID		=> '121',
		#ID field in Accounts table on DB, 
		#use the AName, AID to determine this.
	dbCID		=> '4217',
		#ID field in Character table on DB, 
		#use the AID, CName to determine this.
}
=cut
#my %Characters = {};
my %Characters;

eval {
	#Start bus client.
	$ipc = new Bus::SimpleClient('localhost', $port);
#	$ipc = new Bus::Client(
#		'host' => 'localhost',
#		'port' => $port,
#		'userAgent' => USERAGENT,
#		'privateOnly' => 0
#	);

	##Start database
	startDB();
	##

	## Testing! run a query before starting up the loop,
	# let's see if the database works.
	$sth = $dbh->prepare("SELECT AccountID, Sum(Zeny) as AcctZeny from Characters group by AccountID");
	$sth->execute();

	my ($acctID, $sumZeny) = $sth->fetchrow();
	print "$acctID $sumZeny\n";
	print "=---------=\n";

	##


	# processng loop -- displays bus messages to screen, and
	# accepts input (a few select commands)
	while (1) {
		my $ID;
		while (my $args = $ipc->readNext(\$ID)) {
			processMessage($ID, $args);
		}

		my $input = $interface->getInput(0.02);
		if ($input) {
			processInput(parseArgs($input));
		}
	}
	
	## clean up database connections, etc.
	stopDB();
	##
};
if ($@) {
	print STDERR "Error: $@\n";
	exit 1;
}


## startDB
# Starts:
# - connection to mysql 
# - sets the proper database
#
sub startDB {
	## Todo - load these settings from file so they're not in the code
	## WARNING - cannot github this project until this sort of thing is
	## isolated out, for security reasons.
	##
	#my $dbHost = 'localhost';
	#my $dsn = "dbi:mysql:koreInventory\@$dbHost";
	my $dsn = "dbi:mysql:koreInventory";
	my $dbUser = 'kore';
	my $dbPass = 'iROrules';
	##

	$dbh = DBI->connect(
		$dsn, 
		$dbUser, 
		$dbPass,
		{ RaiseError => 1 }
	) or die $DBI::errstr;
	print "-----\n";
	print "Database connected!\n";
} # startDB()

sub runQuery {
	my ($qStr) = @_;
	
	$sth = $dbh->prepare( $qStr );
	$sth->execute();

	my @result = $sth->fetch();

	#my $result = $sth->fetch();
	$sth->finish();
	return @result;
} # runQuery()

sub stopDB {
	$dbh->disconnect();
}


## void sub processMessage(String <MsgID>, hash of String <Args>)
# 
# processMessage handles incoming bus messages.
# sub-messages found may generate outgoing bus messages.
#
# Based on the processMessage routine from test/busclient-test.pl,
# but expanded to:
# - Properly reply to a HELLO message, which allows this client to be
#   identified on the bus, and thus have other perks like being able to
#   receive broadcast messages on the bus.
# - Implements custom bus messages meant to be passed between this
#   database-linked standalone client, and the "bus2db.pl" plugin.
#
# TODO: break out sub-message areas of the ever-growing if-then-else
# logic, so they are separate routines.
##
sub processMessage {
	my ($MsgID, $args) = @_;

	if ($MsgID eq BM_LISTCLIENTS) {
		print "------- Client list --------\n";
		for (my $i = 0; $i < $args->{count}; $i++) {
			printf "%s: %s\n", $args->{"client$i"}, $args->{"clientUserAgent$i"};
		}
		# Handle optional SEQ, if passed back by server.
		print "--\n";
		print "SEQ = $args->{SEQ}\n" if $args->{SEQ};
		print "----------------------------\n";
		#Message from server: LIST_CLIENTS
		#client0        = 57
		#client1        = 33
		#clientUserAgent0 = OpenKore
		#clientUserAgent1 = bus2db
		#count          = 2
		#IRY            = 1		#Unknown - what is this??
		#SEQ            = foo	#Client passed token, so the client can
		#                    	#track responses.  Looks like it was
		#                    	#meant to be for a SEQuence of numbers,
		#                    	#for a history of clients connected.
		#-----------------------

		## Process client list sent after a HELLO reply
		# Enumerate all openkore clients, invite them to register
		# Remember, the SEQ portion of a HELLO reply is optional,
		# check if it exists, then, check if it's the special token.
		if (($args->{SEQ}) && ($args->{SEQ} eq BMC_LC_SEQ)) { #initial/special list-clients,
			for (my $i = 0; $i < $args->{count}; $i++) {
				my $cidx = $args->{"client$i"};
				my $auth = $Characters{$cidx}->{'Authenticated'}; #should be undef if $cidx has no value, otherwise it's 0 or 1.
				if (!$auth) { $auth = ''; }

				if ('1' ne $auth) {
					if ($args->{"clientUserAgent$i"} eq AUTHORIZED_USERAGENT) {
						printf "Sending a reg request to... %s\n", $cidx;
						initCharactersEntry($args->{$cidx});
						$ipc->send( BMC_REGISTER, { 'TO' => $cidx } );
					}
				}
			}
			print "----------------------------\n";
		}
	} elsif ($MsgID eq BMC_REGISTER_ME) {
		print "----------------------------\n";
		print "Register-me received\n";
		print "from client: $args->{FROM}\n";
		print "----------------------------\n";
		#TODO: parse this - we need to register this client now.
		if (($Characters{$args->{FROM}}) && (!$Characters{$args->{FROM}}{Authenticated})) {
			verifyCharactersEntry( $args->{FROM}, $args->{CName}, $args->{CIdx}, $args->{AName}, $args->{AID} );
		}

	} elsif ($MsgID eq BM_HELLO) {
		print "----------------------------\n";
		print "HELLO received\n";
		## Set our busID to 'sign' messages later...
		$busID = $args->{yourID};
		print "You are ID $busID\n";
		print "----------------------------\n";
		$ipc->send(BM_HELLO, { userAgent => USERAGENT, privateOnly => 0 });
		$ipc->send(BM_LISTCLIENTS, { 'SEQ' => 'f00' });
	} elsif ($MsgID eq BM_JOIN) {
		printf "JOIN : %s@%s\n", $args->{name}, $args->{host};
		print "----------------------------\n";
		#Message from server: JOIN
		#host           = 127.0.0.1
		#clientID       = 55
		#name           = OpenKore:55
		#userAgent      = OpenKore
		#-----------------------

		#Insert entry for the given clientID in %Characters if "OpenKore"
		printf "- add caching data for %s\n", $args->{clientID};
		initCharactersEntry($args->{clientID});
		if ($args->{userAgent} eq AUTHORIZED_USERAGENT) {
			$ipc->send( BMC_REGISTER, { 'TO' => $args->{clientID} } );
		}
		print "----------------------------\n";
	} elsif ($MsgID eq BM_LEAVE) {
		my $clientID = $args->{clientID};
		printf "LEAVE: client %s\n", $clientID;
		#Message from server: LEAVE
		#clientID       = 51
		#-----------------------

		#Remove entry for the given clientID in %Characters :
		if ($Characters{$clientID}) {
			printf "- remove cached data for %s\n", $clientID;
			delete $Characters{$clientID};
		}
		print "----------------------------\n";

	#custom bus messages here
	} elsif ($MsgID eq BMC_ZENY) {
		print "Message from server: $MsgID\n";
		my $clientID = $args->{FROM};
		if ($Characters{$clientID}) {
			if ($Characters{$clientID}{Authenticated} == 1) {
				print "Char $clientID is authenticated - send zeny update!\n";
				printf "Query: %s Values( %s, %s )\n", UPDATE_ZENY, $args->{zeny}, $Characters{$clientID}{dbCID};
				#$sql return value = the number of rows affected by the update -- should be always 1 in this case!
				my $sql = $dbh->do(
					'UPDATE Characters SET Zeny = ? WHERE ID = ?', #statement
					undef,
					$args->{zeny}, #first parameter
					$Characters{$clientID}{dbCID} #second parameter
				);
				$DBI::err && die $DBI::errstr;
				print "$sql row(s) updated\n";
				print "----------------------------\n";

			}
		}
		#Message from server: B2DB_ZENY
		#FROM   = 147
		#change = -3500
		#zeny   = 5149540
		#-----------------------

	#no matches, print it out, maybe we need to support it or debug
	} else {
		print "Message from server: $MsgID\n";
		if (ref($args) eq 'HASH') {
			foreach my $key (keys %{$args}) {
				printf "%-14s = %s\n", $key, $args->{$key};
			}
		} else {
			foreach my $entry (@{$args}) { print "$entry\n"; }
		}
		print "-----------------------\n";
	}
}  #processMessage

sub processInput {
	my @args = @_;
	#print "processInput: @args\n";

	if ($_[0] eq "q" || $_[0] eq "quit") {
		exit;

	} elsif ($_[0] eq "s") {
		if (@_ == 4) {
			print "Sending $_[1]: $_[2] = $_[3]\n";
			$ipc->send($_[1], { $_[2] => $_[3] });
		} else {
			print "Usage: s (ID) (KEY) (VALUE)\n";
			print "Send a message to the server.\n";
		}
	} elsif ($_[0] eq "lc") {
		if (@_ > 1) {
			print "send seq: $_[1] \n";
			$ipc->send(
				"LIST_CLIENTS",
				{ 'SEQ' => $_[1] }
			);
		} else {
			$ipc->send("LIST_CLIENTS");
		}
	} elsif ($_[0] eq "bmsg") {
		if (@_ >= 2) {
			shift @args;
			shift @args;
			my $player = $_[1];
			$ipc->send(
				BMC_MESSAGE, 
				{
					'player' => $_[1],
					'FromName' => CHARNAME,
					'msg' => "@args"
				}
			);
			print "bMsg sent!\n";
			print "-----------------------\n";
		} else {
			print("Usage: bmsg <all|player name|map name> <command>.\n");
		}
	} else {
		print "Unrecognized command $_[0]\n";
		print "Available commands: bmsg, lc, s, quit\n";
	}
}

## initCharactersEntry(<ClientNum>);
#  Sets initial values for a %Characters entry at hash <ClientNum>
#
#  Set up what we DO know right now, even if it's not fully completely 
# populated - we'll wait for the client to "register" with us to get the 
# rest.
#
sub initCharactersEntry {
	my $clientID = shift;
	if (!$clientID) { return }
	print $clientID , "\n";
	$Characters{$clientID} = {
			Authenticated => 0,
			Registering   => 1,

			AName         => '',
			AID           => '',
			CName         => '',
			CIdx          => '',

			dbServer      => 0, #hard code for now?...
			dbAID         => '',
			dbCID         => ''
	}
}

## verifyCharactersEntry(<ClientNum>, <CName> <CIdx> <AName> <AID>);
#
# Upon a client registering, we must verify they have a valid entry in the Database.
#
# Called by a subsection of sub processMessage()
# When complete, the %Characters entry at <ClientNum> will have it's
# Authentication key flagged with value = 1, if the client is valid,
# value = 0, (unchanged) if the client did not validate correctly.
# 
# The calling function should clear it's entry, if found to be invalid
# after calling this routine.
#
sub verifyCharactersEntry {
	my $clientID = shift; #<ClientNum>
	my $CharactersEntry = $Characters{$clientID};
	$CharactersEntry->{CName} = shift; #<CName>
	$CharactersEntry->{CIdx}  = shift; #<CIdx>;
	$CharactersEntry->{AName} = shift; #<AName>;
	$CharactersEntry->{AID}   = shift; #<AID>;

	print "Char Name: \"$CharactersEntry->{CName}\"\n";
	print "Verifying client... \n";
	print "----------------------------\n";
	#Data entered -- now, let's check if it's valid with the DB:


	#Query1: is the character name/index correct? does it return a row?
	# if the row is returned, the row's (ID and AccountID) is stored in $CharactersEntry
	$sth = $dbh->prepare('SELECT ID, AccountID FROM Characters WHERE Name = ? AND CharIdx = ?');
	$sth->execute(
		$CharactersEntry->{CName},
		$CharactersEntry->{CIdx}
	);

	my $result = $sth->fetchrow_hashref();
	$sth->finish();

	#Check for bad results in query1, return early if so:
	if (!$result) { 
		print "Query 1 failed: Name or CharIdx incorrect.\n";
		print "Hint: Check name for typos, and CharIdx is 0-indexed.\n";
		print "---\n";
		return;
	} 
	if (!defined($result->{ID})) {
		print "Early Exit Q1.2\n";
		print "---\n";
		return;
	} 
	if (!defined($result->{AccountID})) {
		print "Early Exit Q1.3\n";
		print "---\n";
		return;
	} 

	$CharactersEntry->{dbCID} = $result->{ID}; #index to Character, in the Characters table.
	$CharactersEntry->{dbAID} = $result->{AccountID}; #index to Account, in the Accounts table.
	undef $result;

	#Query2:
	# the Account name/SID vs the the row that matches the AccountID in the Accounts table.

	$sth = $dbh->prepare('SELECT ID,ServerIdx FROM Accounts WHERE Username = ? AND Number = ?');
	$sth->execute(
		$CharactersEntry->{AName},
		$CharactersEntry->{AID}
	);

	$result = $sth->fetchrow_hashref();
	$sth->finish();

	#Check for bad results in query2
	if (!$result) { 
		print "Early Exit Q2.1\n";
		return;
	} 
	if (!defined($result->{ID})) {
		print "Early Exit Q2.2\n";
		return;
	} 
	if (!defined($result->{ServerIdx})) {
		print "Early Exit Q2.3\n";
		return;
	} 
	if ($CharactersEntry->{dbAID} ne $result->{ID}) {
		print "Early Exit Q2.4\n";
		return;
	}

	$CharactersEntry->{dbServer} = $result->{ServerIdx};
	$CharactersEntry->{Authenticated} = 1; # all checks performed: client Authenticated
	print "Client authenticated!\n";
	print "----------------------------\n";
}

