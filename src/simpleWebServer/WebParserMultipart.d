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
	private bool isVariable;
	private int nlCount;
	
	protected string type;
	protected string[string] disposition;
	protected File *f;
	
	this() {
		getContent = true;
		separator = "\r\n";
		files = [];
		
		isFile = false;
		isVariable = false;
	}
	
	/**
	 * Parse the data
	 *
	 * @return bool true if some parsing was made
	 */
	 override public bool parse() {
	 	
	 	if(boundary == "" && "boundary" in settings) {
	 		boundary = "--" ~ settings["boundary"];
 		}
	 	
	 	if(data.length < boundary.length) {
	 		return false;
 		}
 		
 		//parse data
 		string oldData = "";
 		
 		while(data != oldData) {
 			oldData = data;	 		
 			//search for boundary
 			if(data.indexOf(boundary) > -1) {
 				//if we found the boundary, we start a new variable
 				auto boundaryPos = data.indexOf(boundary);
 				parseVariable(data[0 .. boundaryPos]);
 				
 				//remove all the data before the boundary and the boundary itself from the buffer
 				data = data[boundaryPos + boundary.length .. $];
 					
				//we prepare to read a new variable
				getContent = false;
				
				if(isFile) {
					f.close;
				}
				
				if(disposition !is null) {
					auto lastSeparatorPos = parsedData[disposition["name"]].lastIndexOf(separator);
					
					if(lastSeparatorPos == parsedData[disposition["name"]].length - 2) {
						parsedData[disposition["name"]] = parsedData[disposition["name"]][0..lastSeparatorPos];
					}
				}
				
				type = "";
				disposition = null;
				isFile = false;
				isVariable = false;
				nlCount = 0;
 			} else {
 				
 				if(data.length >= boundary.length * 2) {
 					long ret = parseVariable(data[0 .. boundary.length]);
	 				
	 				if(ret>0) {
	 					data = data[ret..$];
 					}
 				} 
			}
 		}
 		
		return true;
	}
	
	/** 
	 *
	 */
	private long parseVariable(string data) {
		long originalLen = data.length;
	 	
		string oldData = "";
		
		while(data != oldData) {
			oldData = data;
			
			if(getContent && (isFile || isVariable)) {
				if(disposition is null) {
					return originalLen;
				}
		
				//write data in variable
				//get the position of the first separator
				
				//save message
				if(isFile) {
					f.rawWrite(data);
				} 
				
				if(isVariable) {
					parsedData[disposition["name"]] ~= data;
				}
				
				data = "";
			} else {
				//read the variable header
				long pos = data.indexOf(separator); //find the separator
		 					 	
			 	if(pos == -1) {
			    	return originalLen - data.length;
		    	}
			 	
			 	string msg = data[0..pos];
			 	data = data[pos + separator.length..$];
			 	
				pos = msg.indexOf(": ");
			 	
			 	//if is the variable header
			 	if(pos != -1) {
			 		//if we found a variable
			 		auto variable = msg.split(": ");
			 		
			 		if(variable[0] == "Content-Disposition") {
			 			disposition = parseDisposition(variable[1]);
		 			}
			 		
			 		if(variable[0] == "Content-Type") {
			 			type = variable[1];
		 			}
			 		
		    	} else {
		    		if(msg.strip() == "") {
		    			nlCount++;
	    			}
		    		
		    		if(nlCount == 2) {
		    			//if we found an empty line
		    			getContent = true;
		    			
		    			if("filename" in disposition) {
		    				if(disposition["filename"] != "") {
			    				isFile = true;
			    				isVariable = false; 
			    				
			    				string file = settings["path"] ~ disposition["filename"];
			    				f = new File(file, "w");
			    				
			    				files ~= [file];
	    					} else {
			    				isFile = false;
			    				isVariable = true;
    						}
		    				
		    				parsedData[disposition["name"]] = disposition["filename"];
		    				
		    			} else {
		    				parsedData[disposition["name"]] = "";
		    				isFile = false;
		    				isVariable = true;
	    				}
	    			}
	    		}
			}
		}
		
		return originalLen - data.length;
	}
	
	/**
	 * Parse content-disposition message
	 *  
	 * @param string data
	 * @return string[string] associative array with the parsed data
	 */
	private string[string] parseDisposition(string data) {
		string[string] vars;
		
		auto varList = data.split("; ");
		
		foreach( i ; 0..varList.length) {
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