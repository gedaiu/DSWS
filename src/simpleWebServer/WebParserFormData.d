/**
This file is part of DSWS.

DSWS is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or 
any later version.

DSWS is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with DSWS.  If not, see <http://www.gnu.org/licenses/>.
*/

module sws.webParserFormData; 

import sws.webParser; 

import std.socket, core.thread, std.stdio, std.array, std.string, std.conv;
import std.datetime, std.uuid, std.json, std.uri;

class WebParserFormData : WebParser {
	
	/**
	 * Parse the data
	 *
	 * @return bool true if some parsing was made
	 */
	override public bool parse() {
		string remainingData = "";
		 
		//split the string by '&' separator
		string getList[] = data.split("&");
		
		//parse every variable
		for(int i=0; i<getList.length; i++) {
			string msg = to!string(getList[i]);
	    	
	    	//look for '='
	    	long pos = msg.indexOf("="); 
	    	
	    	if(pos != -1) {
	    		//put the variable in the array
	    		parsedData[decodeComponent(msg[0..pos])] = decodeComponent(msg[pos+1..$]);
	    	} else {
	    		if(i+1 == getList.length) {
	    			remainingData = msg;
    			} else {
    				parsedData[decodeComponent(msg)] = "";
				}
    		}
		}
		
		data = remainingData;
		
		return true;
	}
}