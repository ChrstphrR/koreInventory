//Test Suite for kore Inventory database 


// Test connecting to SQL database, outputting to console...
var mysql = require('mysql');

console.log('Starting output');
console.log('');

// Load DB connection data from the json file in the same directory:
var fs = require('fs');

var DisplayStats = require('./DisplayStats.js');
var CR_Utilities = require('./CR_Utilities.js');

var dbData; // = require('./db-host-user-pass.json');
var connection;

////define utility functions:
function highestValue(priceRow) {
	// There are THREE pricing levels, in (usually) decreasing value:
	// RetailValue, WholesaleValue, NPCValue
	// Find largest value of these three, sum up (for each item)
	var HighestValue = priceRow.RetailValue;
	if (priceRow.WholesaleValue > HighestValue) {
		HighestValue = priceRow.WholesaleValue;
	}
	if (priceRow.NPCValue > HighestValue) {
		HighestValue = priceRow.NPCValue;
	}
	return HighestValue;
}//end highestValue()

//callback
function AcctZenySums(err, rows, AccountRows) {
	if (err) {
		throw err;
		return;
	}
	console.log( rows );
	//AccountRows = rows.slice(0); // does copy, but then it's lost outside this anon-function!!

	for(Index in rows) {
		AccountRows.push( JSON.parse( JSON.stringify( rows[Index] ) ) );
	}
	console.log( AccountRows.length );
	console.log( Array.isArray(rows));
	console.log( Array.isArray(AccountRows));
}//end fn AcctZenySums()

////end of utility functions



DisplayStats.ReadJsonFromFile(
	dbData, 
	function (err, data) {
		//if (err) throw err;
		//if (!data) return;
		//connection = DisplayStats.ConnectToDB(mysql, data);
		connection = mysql.createConnection(data);

		//json data loaded -- connect!
		connection.connect();
		connection.query("use koreInventory");

		//Set variables for tracking Characters/Accounts
		var TotalAccounts = 0;
		var TotalCharacters = 0;

		//var strQuery = "SELECT Zeny from Characters";
		var strQuery = "SELECT AccountID, Sum(Zeny) as AcctZeny from Characters group by AccountID";
		var rows = [];
		//var AccountRows = rows.slice(0);
		var AccountRows = [];
		connection.query( 
			strQuery,
			AcctZenySums
		);

		//console.log('AR ' + AccountRows + ', TA ' + TotalAccounts );
		//console.log('AR ' + AccountRows.length );
		//
		var ZenyStats = require('./ZenyStats.js');
		
		
		/*
		ZenyStats.totalAccounts(
			connection,
			0, //first server -- iRO!
			function (err, result) {
				if (!err) {
					//console.log( result[0]['COUNT(ID)'] );
					TotalAccounts = result[0]['COUNT(ID)'];

					for (Index = 1; Index <= TotalAccounts; ++Index) {
						// let's tally up the storage values too for each account:
						//console.log( AccountRows[Index] );
						//console.log( AccountRows[Index].AccountID );
						ZenyStats.StorageValue(connection, Index, function(err, data) {
							if (err) {
								console.log( 'No Zeny to count: ' + err );
								//No Zeny to count: Error: Cannot enqueue Query after invoking quit.
							} else {
								var StorageSum = 0;
								for(Index in data) {
									StorageSum += highestValue(data[Index]);
								}
								console.log( 'Storage value: %sz\n', CR_Utilities.addCommas(StorageSum));
							}
						});
					};

				}
			}
		);
		*/

		//Output total Zeny:
		ZenyStats.TotalZeny(connection, function(err, data) {
			if (err) {
				console.log( 'No Zeny to count: ' + err );
			} else {
				console.log( '\nTotalZeny: %sz', CR_Utilities.addCommas(data) );
			}
		});

		//Output value of items in storage...
		// in progress...
		for (AcctIndex = 1; AcctIndex <= 5; AcctIndex++) {
		
			ZenyStats.StorageValue(connection, AcctIndex, function(err, data) {
				if (err) {
					console.log( 'No Zeny to count: ' + err );
				} else {
					console.log( '\nValue of storage: %j', data );

					var StorageSum = 0;
					for(Index in data) {
						StorageSum += highestValue(data[Index]);
					}
					console.log( 'Storage value: %sz\n', CR_Utilities.addCommas(StorageSum));
				}
			});

		}
		////

		//Output value of items in carts...
		// in progress...
		ZenyStats.CartValue(
			connection, 
			2, //row? .. time to document!
			function(err, data) {
				if (err) {
					console.log( 'No Zeny to count: ' + err );
					return;
				}
				var CR_Utilities = require('./CR_Utilities.js');
				console.log( '\nValue of cart (acct ID 1): %j', data );

				var StorageSum = 0;
				for(Index in data) {
					StorageSum += highestValue(data[Index]);
				}
				console.log( 'Cart value: %sz\n', CR_Utilities.addCommas(StorageSum));
			}
		);
		////

		//Output value of items in carts...
		// in progress...
		ZenyStats.InventoryValue(connection, 2, function(err, data) {
			if (err) {
				console.log( 'No Zeny to count: ' + err );
			} else {
				console.log( '\nValue of Inventory (acct ID 1): %j', data );

				var StorageSum = 0;
				for (Index in data) {
					StorageSum += highestValue(data[Index]);
				}

				console.log( 'Inventory value: %sz\n', CR_Utilities.addCommas(StorageSum));
			}
		});
		////

		connection.end( function(err) {
			//Do something after the connection is gracefully terminated.
			console.log( '' );
			if (err) {
				console.log( 'Ended connection. ' + err );
			} else {
				console.log( 'Ended connection. ' );
			}
		});
	}
);

