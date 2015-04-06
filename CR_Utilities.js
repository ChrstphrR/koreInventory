// CR_Utilities.js
//
//  Contains utility routines of various sorts...
//


// Converts a number into one separated into thousands with commas.
//
// Source:
// http://stackoverflow.com/questions/3753483/javascript-thousand-separator-string-format
//
exports.addCommas = function (nStr) {
	nStr += '';
	x = nStr.split('.');
	x1 = x[0];
	x2 = x.length > 1 ? '.' + x[1] : '';
	var rgx = /(\d+)(\d{3})/;
	while (rgx.test(x1)) {
		x1 = x1.replace(rgx, '$1' + ',' + '$2');
	}
	return x1 + x2;
}
