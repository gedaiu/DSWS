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

module sws.webClient; 

import sws.webServer, sws.webRequest;
import sws.webParser, sws.webParserFormData, sws.webParserHeader, sws.webParserMultipart;
import std.socket, core.thread, std.stdio, std.array, std.string, std.conv;
import std.datetime, std.uuid, std.json, std.uri;

class WebClient : Thread {
	
	Socket currSock;
	WebServer myServer;
	string data;
	WebRequest r;
	
	/**
	 * Create the web client object. This object parse the messages from the 
	 * web client
	 *
	 * @param Socket sock
	 * @param CMServer server
	 */
	this(Socket sock, WebServer server) {
		currSock = sock;
		myServer = server;
		super(&run); 
		
		writeln("run client");
	}
	
	/**
	 * Close the socket
	 */
	~this() {
		
		writeln("end client");
		currSock.close;
	}
	
	/**
	 * Start to receive data from the client
	 */
	private void run() { 
		
		core.memory.GC.disable();
		
		try {
			long bytesRead;
		    char buff[1];
		    
		    bool getContent = false; //this is set to true when i want to receive the message content
		    bool ready = false; //set to true after the message was processed
		    long maxContent = 0; //set the length of the message
		    
		    WebParser contentParser;
		    WebParserHeader headerParser = new WebParserHeader;
		    
		    bool parseAtTheEnd;
		    WebRequest r;
		    
		    //receive data
			while ((bytesRead = currSock.receive(buff)) > 0) {
				string rawData = cast(string) buff[0..bytesRead].idup;
								
				if(!getContent) { //if i parse the headers
					headerParser.push(rawData);
					bool ret = headerParser.parse(); //parse the buffer
					
					if(ret) {
						rawData = "";
						string[string] header = headerParser.get();
						//split first header
					    auto head = header[""].split(" ");
				    
					    string method = to!string(head[0]);
					    string path = to!string(head[1]);
					    string protocol = to!string(head[2]);
				    
					    //strip get variables from path
					    long pos = path.indexOf("?");
					    string get;
				     
					    if(pos > -1) {
						    get = path[pos+1..$];
						    path = path[0..pos];
					    } else {
						    get = "";
					    }
					    
					    //create the request 
					    string uid = to!string(myServer.requestNumber) ~ to!string(Clock.currTime());
					    uid = to!string(md5UUID(uid)); 
					    r = new WebRequest(method, uid, "", path, currSock);
					    r.server = myServer;
					    
					    WebParserFormData getParser = new WebParserFormData();
						getParser.push(get);
						getParser.parse(); 
						
						r.get = getParser.get();
						
						//set the headers in the request
						r.requestHeader = header;
								    
					    //parse Cookies
						if("Cookie" in r.requestHeader) {
							auto cookieList = r.requestHeader["Cookie"].split("; ");
						
							foreach(i ; 0 .. cookieList.length) { 
								string msg = to!string(cookieList[i]);
						    	
						    	pos = msg.indexOf("=");
						    	
						    	if(pos != -1) {
						    		r.cookie[msg[0..pos]] = msg[pos+1..$];
						    	}
							}
						}
					
						//check if the message have a body
						if("Content-Length" in r.requestHeader) { 
							//if the message have content start to receive the message
							maxContent = to!long(r.requestHeader["Content-Length"]) + 1;
							getContent = true;
							ready = false;
							
							//determine the content type
							if("Content-Type" in r.requestHeader) {
								if(r.requestHeader["Content-Type"].indexOf("application/x-www-form-urlencoded") != -1) {
									contentParser = new WebParserFormData();
									parseAtTheEnd = true;
								}
								
								if(r.requestHeader["Content-Type"].indexOf("multipart/form-data") != -1) {
									contentParser = new WebParserMultipart();
									
									auto options = r.requestHeader["Content-Type"].split("; ");
									foreach( i ; 0 .. options.length) {
										string msg = options[i];
										
										if(msg.indexOf("=") != -1) {
											auto val = msg.split("=");
											contentParser.settings[to!string(val[0])] = to!string(val[1]);
										}
									}
									
									contentParser.settings["path"] = r.server.getTempFilePath;
											
									parseAtTheEnd = true;
								}
							}
						} else {
							ready = true; //the request is done
						}
					}
				}
				
				if(getContent) { //receive the message content
					maxContent--;
					contentParser.push(rawData);
					
					if(!parseAtTheEnd) {
						contentParser.parse();
					}
					
					if(maxContent == 0) {
						contentParser.parse();
						
						r.post = contentParser.get();
						
						foreach( i ; 0 .. contentParser.files.length ) {
							r.files[contentParser.files[i]] = contentParser.files[i];
						}
						
						//reset the values
						data = ""; //clear the buffer
						getContent = false; 
						ready = true; //the request is done
					}
				}
				
				if(ready) {
					myServer.processRequest(r); //send the request to the web server
					ready = false; //start a new request
					
					//remove files 
					if(contentParser !is null) {
						foreach( i ; 0..contentParser.files.length) {
							try {
								remove(cast(const(char*)) contentParser.files[i]);
							} catch (Exception e) {
								writeln(e.msg);
							}
						}
					}
					
					//stop receive messages from the client
					if("Connection" in r.headers && r.headers["Connection"] == "close") {
	 					break;
					}
				}
			}
			
			//close the connection
			currSock.close;
		} catch(Exception e) {
			writeln(e.msg);
			stdout.flush;
		} 
		
		core.memory.GC.enable();
		r = null;
	} 
}