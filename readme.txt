===
koreInventory
===

This project is multi-part:


I)
bus2db.pl
---

Plugin for OpenKore, written in perl..
Communicates between the instance of OpenKore and bus2db-client.


II)
bus2db-client.pl
---

Standalone OpenKore Bus client, written in perl.
Communicates over the OpenKore Bus with instances that have the plugin 
bus2db.pl loaded.  Sends updates to character/account info to a mysql 
database.

* Requires access to a JSON file to read database settings.


III)
koreInventory
---

Standalone test scripts for nodejs, that inferface with the mysql 
database and query it for data.

In the future, this will be a web front end, that will help the user see 
big-picture views of what their bot(s) are doing, and/or how productive 
they are.

* Requires access to a JSON file to read database settings. (same 
file/settings as required by bus2db-client.pl)


IV)
koreInventory-schema.sql
---

The schema for the database that II) and III) interact with. You're going to 
need this loaded into mysql, or otherwise, you'll have quite a few errors 
that will fail somewhat silently.

V)

db-host-user-pass.json
---
This is the JSON file mentioned twice, above, that is read to connect to your mysql database.

VI)
Javascript files to run on nodejs:
main.js -- you call this file.
ZenyStats.js
DisplayStats.js

Ugh, keep in mind, I'm still learning the ropes with Javascript, so this is crude at the moment.
In the future, the plan is to make a node application that runs a small webserver/pages that will let you view "executive" data about your accounts, and track metrics, analyze statistics, etc.
But, first I have to plan out what I want to display, after the plugin reports more data to the database.
In summary -- please be patient with the rough edges!



---
Requirements:
---

A) Posix/Unix like OS.

Tested on Linux (ubuntu 14.04), but should function on any Linux, OSX, BSD system, even, in theory, the Posix compliant parts of Windows.

Untested on everything but Ubuntu 14.04, in other words.
Caveat Emptor, and please inform me of any bugs that might be platform specific, so I can attempt to fix them.


B) A mysql database.

From "mysql --version":
mysql  Ver 14.14 Distrib 5.5.41, for debian-linux-gnu (x86_64) using readline 6.3

This was installed as part of the LAMP package on Ubuntu.  Again, caveat emptor, and please report
any bugs or errors with the version you're using, in case there is some version-related differences behind the issues you may encounter.


C) nodejs

From "nodejs --version":
v0.10.25

I assume it should work on other versions, but hey, you know how these things are, and node is still under changes and flux.
YMMV, so caveat emptor, and please report the version you are using, if you encounter bugs or errors.

D) Openkore (which implies installing perl as part of the process)

From "version" in the terminal:
*** OpenKore what-will-become-2.1 ( r8959M ) - Custom Ragnarok Online client ***
This is close to the HEAD release as of this writing, the "m" is part of custom changes I've made locally to report to me when I'm using changes specific to Openkore
that I have created (and not (yet) committed to the public repository on Sourceforge).

Please don't use the "last release" (i.e. 2.0.7) and expect it to work!  This last release is horribly out of date, and it's been common knowledge that you have to
run off of/near the latest repository daily builds to ensure Openkore works with modern RO servers.

If you have errors, you must know how to read your version number from Openkore, or reporting them will be futile. 
"I'm using the latest version" will not mean much at all. :(

If there are changes to the Openkore sources required for this plugin to function, I will do my best to have them committed to the public codebase, and note
revision numbers of Openkore required to work with this plugin as they are required.

Current assumption: You need an Openkore built from the Sourceforge repository, r8965, or newer.


---
Terribly inadequate "install" instructions:
---


Yes, I'll get around to writing out more for this as time goes on.  I will probably walk someone through setting it up, and improve the instructions based on the friction points encountered.

A)
Install your prerequisite programs and daemons:
- Install Openkore. (which means installing perl, among other tools)
- Install mysql; I did this by installing LAMP (Linux, Apache, MySQL, PHP).
- Install nodejs.

B)
Create the koreInventory database on MySQL.
- Create a user for this database.  Record the settings in "db-host-user-pass.json".  
- use the given koreInventory-schema.sql to set up the database and tables.
- You will need to populate:
  - the Servers table with at least one server your Openkore client(s) will connect to.
  - the Account(s) and Character(s) you will connect to, or the plugin and perl script will authenticate.
  Important to note - you must have the Exact character case for your characters, or your plugin will not authenticate properly.
  e.g. If your character name is "Joe", writing "joe" for your character's entry in the Characters table will not match.
- Other tables, at this writing are not critical to fill in, yet, but will matter more when more data is reported from the plugin.

C)
Set up the bus2db-client.pl (standalone perl bus script)
- Copy bus2db-client.pl to your /src directory in Openkore.
  As of this writing, bus2db-client depends on being in the /src directory, to locate modules it needs to load that OpenKore includes.
- Copy db-host-user-pass.json to /src as well.  Make sure it has your settngs in place.

D)
Set up the bus2db.pl plugin:
- Copy bus2db.pl into your /plugins folder, or wherever you specify the plugins are loaded for each of your Openkore clients.
- Check and alter your sys.txt for each openkore client to ensure that the bus2db plugin loads up with your client(s).
  See: 
  How to use Plugins: http://wiki.openkore.com/index.php/Category:Plugins
  Sys.txt: http://wiki.openkore.com/index.php/Category:Sys.txt
  Plugin command: http://wiki.openkore.com/index.php/Plugin
- Ensure the bus is turned on/set up in sys.txt
  Sys.txt: bus: http://wiki.openkore.com/index.php/Bus

E)
Load your OpenKore client, and after it has loaded up, use the "plugin" command to see if it has loaded up.

F)
Once your first Openkore client is loaded, you should check to ensure the Bus server was loaded by Openkore:
Search for /tmp/OpenKore-Bus.info (on *nix), and open that file to see the host and port defined.
e.g.:
	host=127.0.0.1
	port=54321

G)
Launch your standalone bus client, and check that it connects to the bus:

perl /path/to/openkore/src/bus2db-client.pl <PortNumberHere>

It'll give errors if it is NOT given the port on the commandline as a parameter, as of this writing, despite having the busport defined in your JSON file.
In this script, it will accept some simple commands.

H)
To authenticate clients on the bus, type in the list client command, with an extra-special argument.

"lc f00" (no quotes)

This will test the remaining settings, by trying to initiate and register the OpenKore clients attached to the Bus system, and verify the information given by any
responding clients with the mysql database. 
(Remember where it was mentioned you need to spell the Character Names exactly the same in the Characters table? This is where it's checked, and why it matters.)

I) If all was successful, your plugin will not report each time your character either gains or loses zeny, and record the new amount of zeny he/she possesses into the database.
Future updates to this plugin and set of programs will ensure

J) Set up that crude nodejs script that mostly only shows the total zeny of all the accounts/characters connected.
- Make a directory to store the included javascript files
- Copy main.js, DisplayStats.js, ZenyStats.js, db-host-user-pass.json to this directory.
- Check, and update the data inside db-host-user-pass.json
Run the script:
node main.js (or on some systems, nodejs main.js)

Look for an output line starting with "TotalZeny:" on the terminal -- that's how much the database has recorded, for all the connected characters.
(Which is one, if you're run though this once...)

K)
If you have more Openkore clients to connect... well, go through steps D to F as required to set them up as well.




Keep in mind:
The koreInventory system can only record what it can see, simply put.

It will not keep track of your zeny (and in the future, your account/characters' items), if you access your account without using Openkore/bus2db/bus2db-client/database.

So, if you use this system, and then shut down the openkore client, or the plugin, or the standalone script, or the database, the info in the database will not be consistant if you connect to your RO server with just the standard gui game client.  


Please report any issues you have, so I can both improve my instructions here, and fix any bugs.

---
ToDo notes for author:
---

*Improve* Install instructions for each part of the project.

Create and link a trello board for features/bugs/etc.

Fix bugs noted in the code already.

Fix bugs reported in by testers and users.

Look for ToDos in the code, and flesh out more features that make the project components more robust.

Map out more data to track in the plugin/send through the standalone client.

Make the nodejs based "front end" more of a front end, and report more data.




