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

module sws.webServer; 

import std.socket, core.thread;

import core.time;
import std.stdio, std.file, std.string, std.array, std.conv, std.datetime, std.uuid, std.json, std.algorithm;

import sws.webClient, sws.webRequest; 

/**
 * The HTTP server class
 */
class WebServer : Thread {
	
	Socket listener;
	
	synchronized ulong requestNumber = 0;
	synchronized int uploadingClients = 0;
	
	protected string[string] settings;
	
	protected ushort port;
	public bool listening;
	
	protected bool delegate(WebRequest request) pRequest = null;
	
	this() { 
		setPort(80);
		listener = new TcpSocket;
		super(&run);
	}
	
	this(bool delegate(WebRequest request) dg) {
		this();
		pRequest = dg;
	} 
	
	/**
	 * Proces a request. This metod must be called after the request set all the POST, GET, FILES, COOKIES
	 * 
	 * @return bool return true if the process is a success 
	 */
	public bool processRequest(WebRequest request) {
		
		if(pRequest !is null) {
			return pRequest(request);
		} 
		
		return false;
	}
	
	/**
	 * Set the listening port
	 * @param ushort port 
	 */
	void setPort(ushort port) {
		this.port = port;
	}
	
	/**
	 * Start the server
	 */
	private void run() {
		writeln("starting  webserver on port " ~ to!string(port) ~ "...");
		stdout.flush;
		
		listener.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
		bool binded = false;
		
		while(!binded) {
			try {
				listener.bind(new InternetAddress(port));
				binded = true;
			} catch(Exception e) {
				writeln(e.msg);
				stdout.flush;
				
				this.sleep( dur!("seconds")( 2 ) ); // sleep for 2 seconds
			}
		}
		
		listener.listen(1);
		
		writeln("waiting for clients...");
		stdout.flush;
		
		listening = true;
		
		listener.blocking(false);
		
		Socket sock;
		while(listening) { 
			try {
				sock = listener.accept();
			} catch(Exception e) {
				sock = null;
			}
			
			stdout.flush;
			
			if(sock !is null) {
				WebClient webClient = new WebClient(sock, this);
				webClient.start;
			}
			
			this.sleep( dur!("msecs")( 5 ) );
	    }
	}
	
	/**
	 * Get the path where the temporarry files will be uploaded
	 * 
	 * @return string
	 */
	public string getTempFilePath() {
		return "";
	}
	
	/**
	 * Stop the server
	 */
	void stop() {
		writeln("close the listener");
		
		try {
			if(listener.isAlive) {
				listener.close;
			}
		} catch(Exception e) {
			writeln(e.msg);
		}
		
		listening = false;
	}
}
