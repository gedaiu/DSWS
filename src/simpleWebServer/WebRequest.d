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

module sws.webRequest; 

import std.c.stdlib: malloc, free;

import std.socket;
import sws.webServer;
import std.variant;
import std.conv, std.stdio, std.file, std.string, std.path, std.array, std.regex, std.datetime;

//Request class
class WebRequest {
	private Socket mySocket;
	WebServer server;
	private File *requestText;
	private string method = "";
	private string responseData;
	
	public string[string] requestHeader;
	public string[string] cookie;
	public string[string] get;
	public string[string] post;
	public string[string] footer;
	public string[string] files;
	public string[string] headers;
	public Variant[string] data;
	
	private string file;
	
	private string uid;
	
	private string url;
	
	int status_code = 200;
	private string status_message[int];
	private string mime[string];
	
	uint size = 0; //upload data size
	
	/**
	 * Create the Request
	 *
	 * @param string method GET POST PUT DELETE OPTIONS TRACE HEAD allowed
	 * @param string uid an uid for the request
	 * @param string tmp temporary path where we upload files
	 * @param Socket connection 
	 */
	this(string method, string uid, string tmp, string url, Socket sock = null) 
	in {
		int[string] methods = ["GET":0 , "POST":0 , "PUT":0 , "DELETE":0, "OPTIONS":0, "TRACE":0, "HEAD":0];
		assert(method in methods || (method == "__DEFAULT" && sock is null));
	} body {
		this.mySocket = sock;
		this.method = method;
		this.uid = uid;
		this.url = url;
		this.file = "";
		
		//init response headers
		headers["Content-Type"] = "text/html; charset=UTF-8";
		
		//init status messages
		status_message[100] = "Continue";
        status_message[101] = "Switching Protocols";
        status_message[200] = "OK";
        status_message[201] = "Created";
        status_message[202] = "Accepted";
        status_message[203] = "Non-Authoritative Information";
        status_message[204] = "No Content";
        status_message[205] = "Reset Content";
        status_message[206] = "Partial Content";
        status_message[300] = "Multiple Choices";
        status_message[301] = "Moved Permanently";
        status_message[302] = "Found";
        status_message[303] = "See Other";
        status_message[304] = "Not Modified";
        status_message[305] = "Use Proxy";
        status_message[307] = "Temporary Redirect";
        status_message[400] = "Bad Request";
        status_message[401] = "Unauthorized";
        status_message[402] = "Payment Required";
        status_message[403] = "Forbidden";
        status_message[404] = "Not Found";
        status_message[405] = "Method Not Allowed";
        status_message[406] = "Not Acceptable";
        status_message[407] = "Proxy Authentication Required";
        status_message[408] = "Request Time-out";
        status_message[409] = "Conflict";
        status_message[410] = "Gone";
        status_message[411] = "Length Required";
        status_message[412] = "Precondition Failed";
        status_message[413] = "Request Entity Too Large";
        status_message[414] = "Request-URI Too Large";
        status_message[415] = "Unsupported Media Type";
        status_message[416] = "Requested range not satisfiable";
        status_message[417] = "Expectation Failed";
        status_message[500] = "Internal Server Error";
        status_message[501] = "Not Implemented";
        status_message[502] = "Bad Gateway";
        status_message[503] = "Service Unavailable";
        status_message[504] = "Gateway Time-out";
        status_message[505] = "HTTP Version not supported";
        
        //set some mime types
        mime[".html"] = "text/html; charset=UTF-8";
        mime[".htm"] = "text/html; charset=UTF-8";
        mime[".php"] = "text/html";
        mime[".css"] = "text/css";
        mime[".svg"] = "image/svg+xml";
		mime[".ttf"] = "application/x-font-ttf";
		mime[".otf"] = "application/x-font-opentype";
		mime[".woff"] = "application/font-woff";
		mime[".eot"] = "application/vnd.ms-fontobject";
		
		mime[".jpe"] = "image/jpeg";
		mime[".jpe"] = "image/pjpeg";
		mime[".jpeg"] = "image/jpeg";
		mime[".jpeg"] = "image/pjpeg";
		mime[".jpg"] = "image/jpeg";
		mime[".jpg"] = "image/pjpeg";
		mime[".jps"] = "image/x-jps";
		mime[".png"] = "image/png";
		
		writeln("new req");
	}
	
	/**
	 * Get output buffer
	 * @return string
	 */
	string getText() {
		return responseData;
	}
	
	/**
	 * Set output buffer
	 * @return string
	 */
	void sendText(string text) {
		responseData = text;
	}
	
	/**
	  * Add a data to request
	  * @param string valueName value name
	  * @param Variant val
	  */
	void addData(string valueName, Variant val) {
		synchronized { 
			data[valueName] = val;
		}	 
	} 
	
	/**
	  * Clear data from request
	  * @param string mod module name
	  * @param string val value
	  */
	void clearData(string mod) {
		synchronized { 
			data[mod].clear();
		}
	} 
	
	/**
	  * Get data from request
	  *
	  * @param string varName variable name
	  * @return Variant
	  */
	Variant getData(string varName) {
		synchronized { 
			return data[varName];
		}
	} 
	 
	/**
	 * Get the requested url
	 * @return string 
	 */
	string getUrl() {
		return url;
	}
	
	/**
	 * Check if the current url matches the regex
	 *
	 * @param string rule The Regex rule
	 * @param ref string[] param The matching parameters will be stored here
	 * @return bool 
	 */
	bool checkUrl(string rule, ref string[] param) {
		auto r = regex(rule, "i"); 
		
		if(match(url, r)) {
			
			auto m = match(url, r);
			auto params = m.captures;
			
			while(!params.empty) {
				param ~= [params.front];
				params.popFront;
			}
			
			return true;
		}
		
		return false;
	}
	
	/**
	 * Check if the current url matches the regex
	 *
	 * @param string rule The Regex rule
	 * @param ref string[] param The matching parameters will be stored here
	 * @return bool 
	 */
	bool checkUrl(string rule) {
		string[] p;
		return checkUrl(rule, p);
	}
	
	/** 
	 * Add header to request
	 * @param string header header name
	 * @param string value header value
	 */
	void addHeader(string header, string value) {
		headers[header] = value;
	}
	
	/**
	 * Process the variables sent by the client
	 */
	void processVariables() {
		
	} 
	
	
	/**
	 * Create a new session
	 */
	void setCookie(string name, string value) {
		cookie[name] = value;
	}
	
	/**
	 * Get the request method
	 * @return string
	 */
	string getMethod() { 
		return method;
	}
	
	/**
	 * Send string to the client
	 * 
	 * @param string text
	 */
	void send(string text) {
		responseData ~= text;
	}
	
	/**
	 * Send a file to the client
	 * 
	 * @param string filename
	 */
	void sendFile(string filename) {
		file = filename;
	}
	
	/**
	 * Send error to the client
	 * 
	 * @param int err
	 */
	void sendError(int err, string msg = "") {
		string title = to!string(err);
		file = "";
		responseData = "<!doctype html>
		<head>
			<title>" ~ title ~ "</title>
			<meta charset=\"utf-8\" />
		</head>
		<body><h1>" ~ title ~ "</h1><hr/>";
		
		
		if(err == 301 && msg == "") {
			msg = "Content moved here <a href=" ~ msg ~ ">here</a>";
		}
		
		if(err == 307 && msg == "") {
			msg = "Temporary redirect <a href=" ~ msg ~ ">here</a>";
		}
		
		if(err == 404 && msg == "") {
			msg = "Not found";
		}
		
		responseData ~= msg ~ "</body>";
		
		headers["Content-Type"] = "text/html; charset=UTF-8";
		
		file = "";
		status_code = err;
	}
	
	/**
	 * Get the response code 
	 *
	 * @return int
	 */
	int getResponseCode() {
		return status_code;
	}
	
	/**
	 * Flush data to the client
	 */
	public bool flush() {
		//create the response
		if(status_code !in status_message) {
			status_message[status_code] = "Extension";
		}
		
		string response = "HTTP/1.1 " ~ to!string(status_code) ~ " " ~ status_message[status_code] ~ "\r\n";
		
		headers["Server"] = "CMServer/0.1 (Linux)";
		headers["Connection"] = "close";
		
		if(file != "") {
			auto ext = to!string(extension(file));
			
			if(ext in mime) {
				headers["Content-Type"] = mime[ext];
			} else {
				headers["Content-Type"] = "application/octet-stream";
			}
		}
		
		//add the cookies
		string glue = "";
		foreach(string key, string value; cookie) {
			headers["Set-Cookie"] = glue ~ key ~ "=" ~ value;
			glue = "; ";
		}
		
		foreach(string key, string value; headers) {
			response ~= key ~ ": " ~ value ~ "\r\n";
		}
		
		mySocket.send(response);
		
		if(file != "") {
			if(exists(file)) {
				try {
					File *f = new File(file, "r");
					
					mySocket.send("Content-Length: " ~ to!string(getSize(file)) ~ "\r\n");
					mySocket.send("\r\n");
					
					while(!f.eof) {
						char buf[512];
						f.rawRead(buf);
						mySocket.send(buf);
					}
					
					f.close();
				} catch (Error e) {
					sendError(500, e.msg);
					return flush();
				}
				
			} else {
				sendError(404);
				return flush(); 
			}
		} else {
			mySocket.send("Content-Length: " ~ to!string(responseData.length) ~ "\r\n");
			mySocket.send("\r\n");
		
			mySocket.send(responseData);
		}
		
  		return true;
	}
	
	
	string getHeader(string name) {
		if(name in requestHeader) {
			return requestHeader[name];
		}
		
		return "";
	}
	
	string getCookie(string name) {
		if(name in cookie) {
			return cookie[name];
		}
		
		return "";
	}
	
	string getGet(string name) { 
		if(name in get) {
			return get[name];
		}
		
		return "";
	}
	
	string getPost(string name) {
		if(name in post) {
			return post[name];
		}
		
		return "";
	}
	
	string getFooter(string name) {
		if(name in footer) {
			return footer[name];
		}
		
		return "";
	}
	
	string getFiles(string name) {
		if(name in files) {
			return files[name];
		}
		
		return "";
	}
	
	/**
	 * Destroy the request
	 */
	~this() {
		writeln("del req");
	}
}