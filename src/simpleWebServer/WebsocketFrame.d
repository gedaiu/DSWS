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

module sws.websocketFrame; 

import std.stdio;

class WebsocketFrame {
	bool FIN;

	bool RSV1;
	bool RSV2;
	bool RSV3;
	int opcode;
	
	bool haveMask;
	byte mask[4];
	
	string payloadData;
	long length;
	
	
	this() {
		FIN = true;

		RSV1 = false;
		RSV2 = false;
		RSV3 = false;
		
		opcode = 0; 

		haveMask = false;
		mask = 0;
		length = 0;
		payloadData = "";
	}
	
	/** 
	   Encode a message
	 
	   @return string
	 */
	override public string toString() {
		string decoded = "";

		if(length == payloadData.length) {
			foreach(i; 0..payloadData.length) {
				decoded ~= payloadData[i] ^ mask[i % 4];
			}
		}
		
		return decoded;
	}
	
	/**
	 * Encode the frame
	 *
	 * @return string
	 */
	public string encode() {
		string encoded = "";
		
		ubyte b[];
		
		//encode first byte
		ubyte firstByte = cast(ubyte) opcode;
		firstByte |= FIN << 7;
		firstByte |= RSV1 << 6;
		firstByte |= RSV2 << 5;
		firstByte |= RSV3 << 4;
		firstByte |= (opcode & (1 << 4)) << 3;
		firstByte |= (opcode & (1 << 5)) << 2;
		firstByte |= (opcode & (1 << 6)) << 1;
		firstByte |= (opcode & (1 << 7)) << 0;
		
		b ~= [firstByte];
		
		//encode the message length
		ubyte someByte;
		
		if(payloadData.length <= 125) {
			byte l = cast(byte) payloadData.length;
			
			someByte = l;
			someByte |=  cast(ubyte) (haveMask << 7);
			
			b ~= [someByte];
		} else if (payloadData.length <= 255 * 255 - 1) {
			int l = cast(int) payloadData.length;
			someByte = 126;
			someByte |=  cast(ubyte) (haveMask << 7);
			b ~= [someByte];
			
			auto c = (cast(byte*) &l)[0..2];
			b ~= c[1];
			b ~= c[0];
		} else {
			long l = payloadData.length;
			someByte = 127;
			someByte |=  cast(ubyte) (haveMask << 7);
			b ~= [someByte];
			
			ubyte[] c = (cast(ubyte*) &l)[0..8];
			
			foreach(i; 0..8) {
				b ~= c[7-i];
			}
		}
		
		//encode message
		if(haveMask) {
			b ~= mask;
			
			foreach(i; 0..payloadData.length) {
				b ~= payloadData[i] ^ mask[i % 4];
			}
		} else {
		 	b ~= payloadData;
		}
		
		//writeln(b);
		
		/*
		if (this.payloadLength <= 125) {
			secondByte = this.payloadLength;
			secondByte += this.haveMask * 128;

			encoded .= chr(secondByte);
		} else if (this.payloadLength <= 255 * 255 - 1) {
			secondByte = 126;
			secondByte += this.haveMask * 128;

			encoded .= chr(secondByte) . pack("n", this.payloadLength);
		} else {
			secondByte = 127;
			secondByte += this.haveMask * 128;
 
			encoded .= chr(secondByte);
			encoded .= pack("N", 0);
			encoded .= pack("N", this.payloadLength);
		}

		this.mask = 0;
		if (this.haveMask) {
			this.mask = pack("N", rand(0, pow(255, 4) - 1));
			encoded .= this.mask;
		}

		*/
		
		
		return cast(string) b;
	}
}

/*
class WebSocketFrame {
	public payloadLength;
	public payloadData;
	public length;

	//frame header
	public FIN, RSV1, RSV2, RSV3, opcode;

	//masking data
	public haveMask, mask;


	public function __construct() {
		this.FIN = 1;

		this.RSV1 = 0;
		this.RSV2 = 0;
		this.RSV3 = 0;
		this.opcode = 0;

		this.haveMask = 0;
		this.mask = 0;
		this.payloadLength = 0;
	}

	/**
	 * Encode the frame
	 *
	 * @return string
	 */
	/*public function encode() {
		this.payloadLength = strlen(this.payloadData);

		firstByte = this.opcode;
		firstByte += this.FIN * 128 + this.RSV1 * 64 + this.RSV2 * 32 + this.RSV3 * 16;

		encoded = chr(firstByte);

		if (this.payloadLength <= 125) {
			secondByte = this.payloadLength;
			secondByte += this.haveMask * 128;

			encoded .= chr(secondByte);
		} else if (this.payloadLength <= 255 * 255 - 1) {
			secondByte = 126;
			secondByte += this.haveMask * 128;

			encoded .= chr(secondByte) . pack("n", this.payloadLength);
		} else {
			secondByte = 127;
			secondByte += this.haveMask * 128;

			encoded .= chr(secondByte);
			encoded .= pack("N", 0);
			encoded .= pack("N", this.payloadLength);
		}

		this.mask = 0;
		if (this.haveMask) {
			this.mask = pack("N", rand(0, pow(255, 4) - 1));
			encoded .= this.mask;
		}

		if (this.payloadData) {
			if(this.haveMask) {

				if(this.length == this.payloadLength) {
					for (i = 0; i < this.payloadLength; i++) {
						encoded .= this.payloadData[i] ^ this.mask[i % 4];
					}
				}

			} else {
				encoded .= this.payloadData;
			}
		}

		return encoded;
	}


	/**
	 * Decode the frame
	 */
	/*override public string toString() {

		string decoded = "";

		if(this.length == this.payloadLength) {
			for (i = 0; i < this.payloadLength; i++) {
				decoded ~= this.payloadData[i] ^ this.mask[i % 4];
			}
		}

		return decoded;
	}
}*/