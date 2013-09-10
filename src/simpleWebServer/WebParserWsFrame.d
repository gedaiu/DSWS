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

module sws.webParserWsFrame; 

import sws.webParser; 

import std.socket, core.thread, std.stdio, std.array, std.string, std.conv;
import std.datetime, std.uuid, std.json, std.uri;

import sws.websocketFrame;

class WebParserWsFrame : WebParser {
	
	WebsocketFrame frame;
	
	/**
	 * Parse the data
	 *
	 * @return bool true if some parsing was made
	 */
	override public bool parse() {
		parsedData = null;
		
		while(data.length > 2) {
			if(frame is null) {
				frame = new WebsocketFrame();
				
				ubyte b0 = to!ubyte(data[0]);
				ubyte b1 = to!ubyte(data[1]);
				
				//set the frame header
				frame.FIN = (b0 >> 7) & 1;
				frame.RSV1 = (b0 >> 6) & 1;
				frame.RSV2 =(b0 >> 5) & 1;
				frame.RSV3 =(b0 >> 4) & 1;
				
				frame.opcode = (data[0] & 0x0F);

				frame.haveMask = (b1 >> 7) & 1;
				auto len = data[1] & 0x7f;
				
				data = data[2..$];
				
				if (len <= 125) {
					frame.length = len;
				} else if (len == 126) {
					frame.length = data[0] << 8 | data[1];
					data = data[2..$];
				} else if (len == 127) {
					auto l = (cast(long)data[0]) << 56 | 
							 (cast(long)data[1]) << 48 | 
							 (cast(long)data[2]) << 40 | 
							 (cast(long)data[3]) << 32 | 
							 (cast(long)data[4]) << 24 | 
							 (cast(long)data[5]) << 16 | 
							 (cast(long)data[6]) << 8 | 
							 (cast(long)data[7]);
							 
					frame.length = l;
					data = data[8..$];
				}
				
				//set the frame mask
				if (frame.haveMask) {
					frame.mask = cast(byte[]) data[0..4];
					data = data[4..$];
				}
			}
			
			//move data from the buffer to frame
			long availableLength = std.algorithm.min(frame.length - frame.payloadData.length, data.length);
			frame.payloadData ~= data[0..availableLength];
			data = data[availableLength..$];
			
			//add the frame if is done
			if(frame.length == frame.payloadData.length) {
				parsedData[to!string(parsedData.length)] = frame.to!string;
				frame = null;
			}
		}
		
	    return true;
	}
}