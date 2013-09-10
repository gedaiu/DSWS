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

import std.stdio, std.string, std.file, std.path, std.array, std.conv;
import core.thread;

import sws.webServer, sws.webRequest;
 
void main() { 
	
	//create the webserver with delegates
	auto httpDg = delegate(WebRequest request) {
		//find path
		auto path = dirName(__FILE__);
		
		//get file
		auto data = cast(string) read(buildPath(path, "html/ws.html"), 5000);
		
		request.sendText(data);
		request.flush;
		 
		return true;
	};
	
	//create the webserver with delegates
	auto wsDg = delegate(WebRequest request, string message) {
		request.send(message);
		request.flush;
		
		return true;
	};
	
	WebServer delegateServer = new WebServer(httpDg, wsDg);
	delegateServer.setPort(8080);
	
	//start the server
	delegateServer.start();
	
	//wait the user input and stop the server
	readln;
	delegateServer.stop();
	writeln("Done!!!");
}      