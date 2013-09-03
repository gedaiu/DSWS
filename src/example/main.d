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

import std.stdio, std.string, std.regex;
import core.thread;

import sws.webServer, sws.webRequest;
 
class DemoServer : WebServer {
	
	this() {
		super();
		setPort(8080);
	}
	
	/**
	 * Implementing the method that process the requests
	 *
	 */
	override bool processRequest(WebRequest request) {
		request.sendText("Demo page");
		request.flush;
		return true;
	}
}

void main() { 
	
	//create the webserver with delegates
	
	auto dg = delegate(WebRequest request) {
		
		request.sendText("Demo page");
		request.flush;
		
		return true;
	};
	
	WebServer delegateServer = new WebServer(dg);
	delegateServer.setPort(8080);
	
	//or extend the base web server
	DemoServer myServer = new DemoServer();
	
	//start the server
	myServer.start();
	
	//wait the user input and stop the server
	readln;
	myServer.stop();
	writeln("Done!!!");
}      