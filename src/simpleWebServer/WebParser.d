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

module sws.webParser; 

import std.socket, core.thread, std.stdio, std.array, std.string, std.conv;
import std.datetime, std.uuid, std.json, std.uri;

class WebParser {
	
	protected string data;  
	protected string[string] parsedData;
	string[string] settings;
	public string[] files;
	
	/**
	 * Push data into parser
	 *
	 * @param string data
	 */
	public void push(string data) {
		this.data ~= data;
	}
	
	/**
	 * Return the parser buffer
	 *
	 * @return string
	 */
	public string getData() {
		return data;
	}
	
	/**
	 * Parse the data
	 *
	 * @return bool true if some parsing was made
	 */
	abstract public bool parse();
	
	/**
	 * Get the parsed data
	 *
	 * @return string[string]
	 */
	public string[string] get() {
		return parsedData;
	}
	
}
