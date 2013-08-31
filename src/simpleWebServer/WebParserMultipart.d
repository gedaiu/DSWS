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

module sws.webParserMultipart; 

import sws.webParser; 

import std.socket, core.thread, std.stdio, std.array, std.string, std.conv;
import std.datetime, std.uuid, std.json, std.uri, std.file;
 
class WebParserMultipart : WebParser {
	
	public string boundary;
	public string separator;
	private bool getContent;
	private bool isFile;
	
	protected string type;
	protected string[string] disposition;
	protected File *f;
	
	this() {
		getContent = false;
		separator = "\r\n";
		files = [];
	}
	
	/**
	 * Parse the data
	 *
	 * @return bool true if some parsing was made
	 */
	 override public bool parse() {
	 	
	 	if(boundary == "" && "boundary" in settings) {
	 		boundary = settings["boundary"];
 		}
	 	
	 	if(data.length <= boundary.length) {
	 		return false;
 		}

 		string tsep = "\r\n--" ~ boundary ~ "\r\n";
 		while(data.length >= tsep.length) {
			if(!getContent) {
			 	long pos = data.indexOf(separator);
			 	
			 	int add = 3;
			 	
			 	if(pos == -1) {
			    	return false;
		    	}
			 	
			 	string msg = data[0..pos];
			 	data = data[pos+separator.length..$];
			 	
			 	pos = msg.indexOf(": ");
			 	
			 	if(pos != -1) {
			 		auto variable = msg.split(": ");
			 		
			 		if(variable[0] == "Content-Disposition") {
			 			disposition = parseDisposition(variable[1]);
		 			}
			 		
			 		if(variable[0] == "Content-Type") {
			 			type = variable[1];
		 			}
			 		
		    	} else {
		    		if(msg.strip() == "") {
		    			getContent = true;
		    			
		    			if("filename" in disposition) {
		    				isFile = true;
		    				
		    				string file = settings["path"] ~ disposition["filename"];
		    				f = new File(file, "w");
		    				parsedData[disposition["name"]] = disposition["filename"];
		    				files ~= [file];
		    			} else {
		    				parsedData[disposition["name"]] = "";
		    				isFile = false;
	    				}
	    			}
	    		}
			 	
			} else {
				//we found a boundary
				if(data[0..tsep.length] == tsep) {
					getContent = false;
					
					if(data[0..tsep.length] == tsep) {
						data = data[tsep.length .. $];
					}
					
					if(isFile) {
						f.close;
					}
					
					type = "";
					disposition = null;
				} else {
					string msg = to!string(data[0]);
					data = data[1..$];
					
					if(isFile) {
						f.rawWrite(msg);
					} else {
						parsedData[disposition["name"]] ~= msg;
					}
				} 
			}
		}
 		
 		stdout.flush;
 		
		return true;
	}
	  
	private string[string] parseDisposition(string data) {
		string[string] vars;
		
		auto varList = data.split("; ");
		
		for(int i=0; i<varList.length; i++) {
			auto pos = varList[i].indexOf("=");
			
			if(pos == -1) {
				vars[""] = varList[i];
			} else {
				auto variable = varList[i].split("=");
				
				auto pos1 = variable[1].indexOf("\"")+1;
				auto pos2 = variable[1].lastIndexOf("\"");
				
				vars[variable[0]] = (variable[1])[pos1..pos2];
			}
		}
		
		return vars;
	}
	 
}