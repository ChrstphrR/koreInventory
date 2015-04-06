//DisplayStats.js
//
// pulled code from main.js to do the manipulation/queries/display of
// data pulled from the database.
//

exports.ReadJsonFromFile = function(data, callback) {  
	//Reading database config file, pass back the data, or an error in
	// the supplied callback for the calling code to check.
	var fs = require('fs');
	fs.readFile(
		'db-host-user-pass.json', 
		'utf8', 
		function (err, data) {
			//console.log(data); //crude debugging
			
			if (err) {
				callback(err, null);
			} else {
				callback(null, JSON.parse(data));
			}
		}
	);
}


exports.ConnectToDB = function(mysql, loginJson) {
	if (loginJson) {
		return mysql.createConnection(loginJson);
	} else {
		return null;
	}
}
