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

module sws.webParserHeader; 

import sws.webParser; 

import std.socket, core.thread, std.stdio, std.array, std.string, std.conv;
import std.datetime, std.uuid, std.json, std.uri;

class WebParserHeader : WebParser {
	
	/**
	 * Parse the data
	 *
	 * @return bool true if some parsing was made
	 */
	override public bool parse() {
		string separator;
		
		if(data.indexOf("\n\n") == -1 && data.indexOf("\r\n\r\n") == -1) {
	    	return false;
    	}
	     
	    long lastPos = 0;
	    long pos = 0;
	    	
    	if(data.indexOf("\n\n") > -1) {
    		lastPos = data.indexOf("\n\n");
    		separator = "\n\n";
		} else {
			lastPos = data.indexOf("\r\n\r\n");
    		separator = "\r\n\r\n";
		}
	    
	    //split headers
	    auto messages = data.splitLines;
	    
	    if(messages.length == 0) {
	    	data = "";
	    	return false;
    	}
	    
	    parsedData[""] = messages[0];
	    
	    //parse headers
	    foreach(i ; 1..messages.length) {
	    	string msg = to!string(messages[i]);
	    	
	    	pos = msg.indexOf(": ");
	    	
	    	if(pos != -1) {
	    		parsedData[msg[0..pos]] = msg[pos+2..$];
	    	}
	    }
	   
	    data = data[lastPos+separator.length-1 .. $];
	    
	    return true;
	}
}