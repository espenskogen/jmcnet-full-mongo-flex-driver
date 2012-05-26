package jmcnet.mongodb.documents
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;

	/**
	 * A class storing a Cursor from Database.
	 */
	public class Cursor
	{
		public var highValue:uint=0;
		public var lowValue:uint=0;
		private var _n:Number;
		
		/**
		 * Build an new Cursor from high and low value decoded from BSON message
		 */
		public function Cursor(h:uint, l:uint) {
			highValue = h;
			lowValue = l;
			_n = h * 0x100000000 + l;
		}
		
		public function toBSON():ByteArray {
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			ba.writeUnsignedInt(lowValue);
			ba.writeUnsignedInt(highValue);
			
			return ba;
		}
		
		public function toString():String {
			return "0x"+highValue.toString(16)+"-0x"+lowValue.toString(16);
		}
	}
}