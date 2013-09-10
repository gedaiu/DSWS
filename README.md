DSWS - a D Simple web server 
============================

About the project
-----------------

This is a basic HTTP web server with websocket support implemented in D2 using phobos library. The project is intended to be as simple to use, lightweight and free of external libraries other than Phobos. 

Websocket implementation is according rfc6455(http://tools.ietf.org/html/rfc6455) and it's not fully tested, but it should work with: 
 - Chrome 16 +
 - Firefox 11 + 
 - Opera 12.10 + / Opera Mobile 12.1 +


How to use it
-------------

There are two ways to use the server:

1. Extending the WebServer class
	
		import sws.webServer, sws.webRequest;

		class DemoServer : WebServer {
		
			this() {
				super();
				setPort(8080);
			}
			
			/**
			 * Implementing the method that process the HTTP
			 * requests
			 *
			 */
			override bool processRequest(WebRequest request) {
				request.sendText("Demo page");
				request.flush;
				return true;
			}

			/**
			 * Implementing the method that process the
			 * websocket messages
			 *
			 */
			override bool processMessage(WebRequest request) {
				request.sendText("sample message");
				request.flush;
				return true;
			}
		}

		....

		DemoServer myServer = new DemoServer;
		myServer.start;


2. Using delegates
	
		import sws.webServer, sws.webRequest;

		void main() {

			//create the HTTP request delegate
			auto httpDg = delegate(WebRequest request) {
				request.sendText("Demo page");
				request.flush;
				return true;
			};


			//create the websocket message delegate
				auto wsDg = delegate(WebRequest request, string message) {
				request.send("Demo message");
				request.flush;
				
				return true;
			};

			WebServer delegateServer = new WebServer(httpDg, wsDg);
			delegateServer.setPort(8080);
			
			//start the server
			delegateServer.start();
		}


Roadmap
-------

1. Improve documentation
2. Test & search for bugs



Authors
-----------------
[Szabo Bogdan](https://github.com/gedaiu)
