//ZenyStats.js
//

// total zeny across all characters
// Assumptions: 
//	connection -- to a mysql database, already connected
//	callback is a function defined on the calling side, to handle returned data.
//
exports.TotalZeny = function(connection, callback) {
	connection.query(
		"SELECT Sum(Zeny) AS TotalZeny FROM Characters", 
		function(err, result) {
			if (err) {
				callback(err, null);
			}
			else {
				callback(null, result[0].TotalZeny);
			}
		}
	);
};



// Value of storage items.
// Assumptions: 
//	connection -- to a mysql database, already connected
//	callback is a function defined on the calling side, to handle returned data.
//
exports.StorageValue = function(connection, AcctIndex, callback) {
	connection.query(
		//Boy, I should check this before just passing it along... :P
		//"SELECT * from ItemsInStorage Where AccountID = " + AcctIndex,
		//"SELECT ItemID, Count from ItemsInStorage Where AccountID = " + AcctIndex,
		//"SELECT ItemID, Count from ItemsInStorage JOIN ItemValues On ItemsInStorage.ItemID = ItemValues.ID Where AccountID = " + AcctIndex,
		//"SELECT ItemID, Count, Wholesale, Retail, NPCSell from ItemsInStorage JOIN ItemValues On ItemsInStorage.ItemID = ItemValues.ID Where AccountID = " + AcctIndex,
		"SELECT ItemID, Count, Count * Wholesale As WholesaleValue, Count * Retail AS RetailValue, Count * NPCSell AS NPCValue from ItemsInStorage JOIN ItemValues On ItemsInStorage.ItemID = ItemValues.ID Where AccountID = " + AcctIndex + ";",
		//
		function(err, result) {
			if (err) {
				callback(err, null);
			}
			else {
				callback(null, result);
			}
		}
	);
};


exports.totalAccounts = function(connection, ServerIndex, callback) {
	connection.query(
		//Boy, I should check this before just passing it along... :P
		"SELECT COUNT(ID) FROM Accounts WHERE ServerIdx = " + ServerIndex, //+ ";",
		//
		function(err, result) {
			if (err) {
				callback(err, null);
			}
			else {
				callback(null, result);
			}
		}
	);
};


// Value of Cart items.
// Assumptions: 
//	connection -- to a mysql database, already connected
//	callback is a function defined on the calling side, to handle returned data.
//
exports.CartValue = function(connection, CharID, callback) {
	connection.query(
		//Boy, I should check this before just passing it along... :P
		//"SELECT ItemID, Count, Count * Wholesale As WholesaleValue, Count * Retail AS RetailValue, Count * NPCSell AS NPCValue from ItemsInStorage JOIN ItemValues On ItemsInStorage.ItemID = ItemValues.ID Where AccountID = " + AcctIndex,
		"SELECT ItemID, Count, Count * Wholesale As WholesaleValue, Count * Retail AS RetailValue, Count * NPCSell AS NPCValue from ItemsInCart JOIN ItemValues On ItemsInCart.ItemID = ItemValues.ID Where CharacterID = " + CharID,
		//
		function(err, result) {
			if (err) {
				callback(err, null);
			}
			else {
				callback(null, result);
			}
		}
	);
};


// Value of Inventory items.
// Assumptions: 
//	connection -- to a mysql database, already connected
//	callback is a function defined on the calling side, to handle returned data.
//
exports.InventoryValue = function(connection, CharID, callback) {
	connection.query(
		//Boy, I should check this before just passing it along... :P
		"SELECT ItemID, Count, Count * Wholesale As WholesaleValue, Count * Retail AS RetailValue, Count * NPCSell AS NPCValue from ItemsInInventory JOIN ItemValues On ItemsInInventory.ItemID = ItemValues.ID Where CharacterID = " + CharID,
		//
		function(err, result) {
			if (err) {
				callback(err, null);
			}
			else {
				callback(null, result);
			}
		}
	);
};


