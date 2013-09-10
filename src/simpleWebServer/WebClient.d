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

import sws.webServer, sws.webRequest, sws.websocketFrame;
import sws.webParser, sws.webParserWsFrame, sws.webParserFormData, sws.webParserHeader, sws.webParserMultipart;

import std.socket, core.thread, std.stdio, std.array, std.string, std.conv;
import std.datetime, std.uuid, std.json, std.uri;
import std.digest.sha, std.base64;

class WebClient : Thread {
	
	Socket currSock;
	WebServer myServer;
	string data;
	WebRequest r;
	WebParser contentParser;
	
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
	}
	
	/**
	 * Start to receive data from the client
	 */
	private void run() { 
		
		try {
			long bytesRead;
		    char buff[512];
		    
		    bool getContent = false; //this is set to true when i want to receive the message content
		    bool ready = false; //set to true after the message was processed
		    bool isWebsocket = false; // set to true if the current connection is a webbsocket connection
		    
		    WebParserHeader headerParser = new WebParserHeader;
		    WebParserWsFrame wsParser = new WebParserWsFrame;
		    
		    bool parseAtTheEnd;
		    WebRequest r;
		    
		    //receive data
			while ((bytesRead = currSock.receive(buff)) > 0) {
				string rawData = cast(string) buff[0..bytesRead].idup;
				
				if(isWebsocket) {
					wsParser.push(rawData);
					bool ret = wsParser.parse(); //parse the buffer
					
					auto messages = wsParser.get();

					foreach(i; 0 .. messages.length) {
						myServer.processMessage(r, messages[i.to!string]); //send the request to the web server
					}
				}
				
				if(!getContent && !isWebsocket) { //if i parse the headers
					headerParser.push(rawData);
					bool ret = headerParser.parse(); //parse the buffer
					
					rawData = headerParser.leftBehind();
					
					if(ret) {
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
							r.cookie = parseVarList(r.requestHeader["Cookie"]);
						}
					
						//check if the message have a body
						if("Content-Length" in r.requestHeader) {
							parseContent(r, rawData);
						}
						
						ready = true; //the request is done
					}
				}
				
				if(ready) {
					//process the request
					isWebsocket = processConnection(r);
					
					if(isWebsocket) {
						getContent = false;
					} else {
						if("Connection" !in r.requestHeader || ("Connection" in r.requestHeader && r.requestHeader["Connection"] == "close")) {
							r.headers["Connection"] = "close";
						}
					}
					
					ready = false;
					
					//remove files 
					if(contentParser !is null) {
						foreach( i ; 0..contentParser.files.length) {
							try {
								remove(cast(const(char*)) contentParser.files[i]);
							} catch (Exception e) {
								writeln(e);
							}
						}
					}
					
					//stop receive messages from the client
					if("Connection" in r.headers && r.headers["Connection"] == "close") {
						break;
					} else {
						getContent = false; //this is set to true when i want to receive the message content
					    ready = false; //set to true after the message was processed
					    
					    headerParser = new WebParserHeader;
					    wsParser = new WebParserWsFrame;
					}
				}
			}
			
			//close the connection
			currSock.close;
		} catch(Exception e) {
			writeln(e); 
			stdout.flush;
			currSock.close;
		} 
		
		r = null;
	} 
	
	private void parseContent(WebRequest r, string rawData) {
		
		//if the message have content start to receive the message
		long maxContent = to!long(r.requestHeader["Content-Length"]) + 1;
		bool parseAtTheEnd;
		
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
						
				parseAtTheEnd = false;
			}
		}
		
		//receive the message content
		long bytesRead;
		char buff[1024];
		
		while ((bytesRead = currSock.receive(buff)) > 0) {
			rawData ~= cast(string) buff[0..bytesRead].idup;
			
			maxContent -= rawData.length;
			
			contentParser.push(rawData);
			if(!parseAtTheEnd) {
				contentParser.parse();
			}
			
			if(maxContent <= 0) {
				contentParser.parse();
				
				r.post = contentParser.get();
				
				foreach( i ; 0 .. contentParser.files.length ) {
					r.files[contentParser.files[i]] = contentParser.files[i];
				}
				
				break; //break the loop
			}
			
			rawData = "";
		}
		
		stdout.flush;
	}
	
	/**
		Parse a string with variables (var1=val1; var2=val2)
	*/
	private string[string] parseVarList(string list) {
		string[string] varList;
		
		auto cookieList = list.split("; ");
						
		foreach(i ; 0 .. cookieList.length) { 
			string msg = to!string(cookieList[i]);
	    	
	    	auto pos = msg.indexOf("=");
	    	
	    	if(pos != -1) {
	    		varList[msg[0..pos]] = msg[pos+1..$];
	    	}
		}

		return varList;
	}
	
	/**
		Process a request
	
		returns: 
			true if is websocket 
			false if is http request
	*/
	private bool processConnection(WebRequest r) {
		
		//check if is websocket
		if("Upgrade" in r.requestHeader && r.requestHeader["Upgrade"] == "websocket") {
			//start the web socket
			
			r.statusCode = 101;
			
			auto key = strip(r.requestHeader["Sec-WebSocket-Key"]) ~ "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
			
			auto sha1 = new SHA1;
	        sha1.put(cast(ubyte[]) key);
	        auto secretCode = to!string(Base64.encode(sha1.finish()));
			 
			r.headers = [
				"Upgrade": "websocket",
				"Connection": "Upgrade",
				"Sec-WebSocket-Accept": secretCode
			];
			 
			r.flush();
			
			r.websocket = true;
			return true;
		} else {
			myServer.processRequest(r); //send the request to the web server
		}
		
		return false;
	}
}