/**
 * Piece of code taken from there : http://words.transmote.com/wp/20120402/mongodb-objectid-for-as3/
 * NetworkInfo and NetworkInterface are not known in a non AIR environment -> so relative pieces of code are commented.
 */ 

package jmcnet.mongodb.documents
{
//	import flash.net.NetworkInfo;
//	import flash.net.NetworkInterface;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	public class ObjectID {
		private static var incrementer : uint = Math.random() * uint.MAX_VALUE;
		private static var machineAndProcessID : ByteArray = null;
		
		// BSON is little-endian
		private var rep : ByteArray;
		private var time : uint;
		
		/**
		 * @brief Create a new ObjectID
		 * @param bytearray A little-endian, 12-byte ByteArray containing the ID
		 */
		public function ObjectID( bytearray : ByteArray = null ) :void {
			if (bytearray == null) {
				bytearray = generateObjectID();
			}
			setFromBytes( bytearray );
		}
		
		/**
		 * @brief creates a new ObjectID from a String
		 * @param String the _id value
		 */
		public static function createFromString(value:String):ObjectID {
			var ba:ByteArray = new ByteArray();
			ba.writeUTF(value);
			// insert more char if needed to have 12 chars
			while (ba.length < 12) {
				ba.writeByte(0);
			}
			ba.position = 0;
			var o:ObjectID = new ObjectID(ba);
			return o;
		}
		
		/**
		 * @brief Set the value of this ObjectID
		 * @param bytearray A little-endian, 12-byte ByteArray containing the ID
		 */
		public function setFromBytes( bytearray : ByteArray ) :ObjectID {
			rep = new ByteArray();
			for ( var i : int = 0; i < 12; ++i ) {
				rep[i] = bytearray.readByte();
			}
			
			time = rep.readUnsignedInt();
			rep.position = 0;
			
			return this;
		}
		
		
		
		/**
		 * @brief Get the value of this ObjectID
		 * @return A little-endian, 12-byte ByteArray containing the ID
		 */
		public function getAsBytes() : ByteArray {
			return rep;
		}
		
		/**
		 * @brief Returns a formatted readable string
		 */
		public function toString() : String {
			var str:String = "";
			for ( var i : int = 0; i < 12; ++i ) {
				if (rep[i] < 17) {
					str += "0"+rep[i].toString( 16 );
				}
				else str += rep[i].toString( 16 );
			}
			return str;
		}
		
		/**
		 * @brief create a new ObjectID from it's string representation (generated by toString). 
		 * @param String : must be a 24 characters String containing only hexadecimal digits (0-9a-f)
		 * @see ObjectID.toString, Object.createFromString
		 */
		public static function fromStringRepresentation(s:String):ObjectID {
			if (s == null || s.length != 24) return null;
			var ba:ByteArray = new ByteArray();
			for (var i : int = 0; i < 24; i+=2) {
				var t:String = "0x"+s.substr(i, 2);
				ba.writeByte(uint(t));
			}
			ba.position = 0;
			var ret:ObjectID = new ObjectID();
			return ret.setFromBytes(ba);
		}
		
		public function toDate() : Date {
			return new Date( time * 1000 );
		}
		
		private function generateObjectID() :ByteArray {
			// from: http://www.mongodb.org/display/DOCS/Object+IDs
			
			// 4-byte timestamp
			time = new Date().getTime();
			var timeBytes:ByteArray = new ByteArray();
			timeBytes.endian = Endian.BIG_ENDIAN;
			timeBytes.writeInt( time );
			timeBytes.length = 4; // truncate as needed
			
			// 3-byte machine id + 2-byte process id
			if ( machineAndProcessID == null ) {
				generateMachineID();
			}
			
			// 3-byte increment
			var incBytes:ByteArray = new ByteArray();
			incBytes.endian = Endian.BIG_ENDIAN;
			incBytes.writeUnsignedInt( incrementer++ );
			incBytes.length = 3; // truncate as needed
			
			var idBytes:ByteArray = new ByteArray();
			idBytes.writeBytes( timeBytes );
			idBytes.writeBytes( machineAndProcessID );
			idBytes.writeBytes( incBytes );
			
			idBytes.position = 0;
			return idBytes;
		}
		
		private function generateMachineID() :void {
			machineAndProcessID = new ByteArray();
			machineAndProcessID.endian = Endian.LITTLE_ENDIAN;
			
			var useRandom:Boolean = true;
//			for each ( var i : NetworkInterface in NetworkInfo.networkInfo.findInterfaces() ) {
//				if ( i.hardwareAddress ) {
//					machineAndProcessID.writeUTFBytes( i.hardwareAddress );
//					useRandom = false;
//					break;
//				}
//			}
			
			if ( useRandom ) {
				// if no NetworkInterfaces with valid hardware addresses found, use random
				var randomMachineID : uint = Math.floor( Math.random() * uint.MAX_VALUE );
				machineAndProcessID.writeUnsignedInt( randomMachineID );
			}
			
			machineAndProcessID.length = 3; // truncate as needed
			
			// not possible to get process id from flash without launching a NativeProcess,
			// which requires AIR application with extendedDesktop profile.
			// so, use a random.
			var processID:uint = Math.floor( Math.random() * uint.MAX_VALUE );
			machineAndProcessID.writeUnsignedInt( processID );
			
			machineAndProcessID.length = 5; // truncate as needed
		}
	}
}