package jmcnet.mongodb.bson
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;

	public class HelperByteArray
	{
		private static const INDENT:String="    "; 
		public function HelperByteArray() {	}
		
		public static function byteArrayToString(ba:ByteArray):String {
			var result:String="";
			ba.position=0;
			while (ba.bytesAvailable > 0) {
				var c:int = ba.readByte();
				if (ba.position != 1) result += " ";
				if (c < 0) c += 256;
				result += "0x"+c.toString(16);
			}
			return result;
		}
		
		/**
		 * Recursive function transforming a BSON document (or a suite of BSON document) to readable String
		 */
		public static function bsonDocumentToReadableString(ba:ByteArray):String {
			if (ba == null) return "";
			ba.position = 0;
			ba.endian = Endian.LITTLE_ENDIAN;
			var result:String="";
			
			while (ba.bytesAvailable > 0) {
				if (ba.position > 0) result +=",\n";
				result += "{\n"+bsonReadDocument(ba, "")+"\n}";
			}
			return result;
		}
		
		private static function bsonReadDocument(ba:ByteArray, indent:String=""):String {
			// New document			
			var length:uint=ba.readUnsignedInt();
			return bsonReadElements(ba, indent+INDENT);
		}
		
		private static function bsonReadElements(ba:ByteArray, indent:String=""):String {
			var result:String="";
			var first:Boolean=true;
			// Element type
			var type:uint=ba.readByte();
			try {
				while (type != BSONEncoder.BSON_TERMINATOR) {
					if (!first) {
						result += ",\n";
					}
					result += indent;
					switch (type) {
						case BSONEncoder.BSON_DOUBLE :
							result += bsonReadCString(ba) +" : "+ ba.readDouble();
							break;
						case BSONEncoder.BSON_STRING :
							result += bsonReadCString(ba) +" : \""+ bsonReadString(ba)+"\"";
							break;
						case BSONEncoder.BSON_DOCUMENT :
							result += bsonReadCString(ba) +" : {\n"+ bsonReadDocument(ba, indent+INDENT) + "\n"+indent+" }";
							break;
						case BSONEncoder.BSON_ARRAY :
							result += bsonReadCString(ba) +" : [\n"+ bsonReadDocument(ba, indent+INDENT) + "\n"+indent+" ]";
							break;
						case BSONEncoder.BSON_OBJECTID :
							result += bsonReadCString(ba) +" : \""+ bsonReadObjectID(ba).toString()+"\"";
							break;
						case BSONEncoder.BSON_BOOLEAN :
							result += bsonReadCString(ba) +" : "+ (ba.readByte() == BSONEncoder.BSON_TERMINATOR ? "false":"true");
							break;
						case BSONEncoder.BSON_UTC :
							result += bsonReadCString(ba) +" : "+ bsonReadUTC(ba).toString();
							break;
						case BSONEncoder.BSON_NULL :
							result += bsonReadCString(ba) +" : null";
							break;
						case BSONEncoder.BSON_INT32 :
							result += bsonReadCString(ba) +" : "+ ba.readInt();
							break;
						default :
							throw new ExceptionJMCNetMongoDB("BSON decoder : TypeElement : '"+type+"' not implemented");
					}
					first= false;
					type=ba.readByte();
				}
			} catch (e:ExceptionJMCNetMongoDB) {
				throw e;
			} catch (e1:Error) {
				throw new ExceptionJMCNetMongoDB("Error decoding BSON near : '"+result+"' Error is :"+e1.message);
			}
			
			return result;
		}
		
		private static function bsonReadCString(ba:ByteArray):String {
			var str:String = "";
			var char:uint  = ba.readByte();
			while (char != BSONEncoder.BSON_TERMINATOR)
			{
				str += String.fromCharCode(char);
				char = ba.readByte();
			}
			return str;
		}
		
		private static function bsonReadObjectID(ba:ByteArray):ObjectID {
			return new ObjectID(ba);
		}
		
		private static function bsonReadString(ba:ByteArray):String {
			var length:uint = ba.readInt();
			var res:String  = ba.readMultiByte(length - 1, "utf-8");
			ba.readByte(); 
			return res;
		}
		
		private static function bsonReadUTC(ba:ByteArray):Date
		{
			var lowPos:uint  = ba.readUnsignedInt();
			var highPos:uint = ba.readUnsignedInt();
			var rep:Number   = (highPos * 256 * 256 * 256 * 256) + lowPos;
			
			return new Date(rep);
		}
	}
}