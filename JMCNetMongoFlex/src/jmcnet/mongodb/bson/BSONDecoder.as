package jmcnet.mongodb.bson
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.documents.DBRef;
	import jmcnet.mongodb.documents.JavaScriptCode;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;
	
	import mx.utils.ObjectUtil;

	public class BSONDecoder
	{
		public static var logBSON:Boolean = false;
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(BSONDecoder);
		
		
		private static const INDENT:String="    "; 
		public function BSONDecoder() {	}
		
		/**
		 * Recursive function transforming a BSON to MongoDocument
		 */
		public static function decodeBSONToMongoDocument(ba:ByteArray):MongoDocument {
			if (ba == null) return null;
			// ba.position = 0;
			ba.endian = Endian.LITTLE_ENDIAN;
			var result:MongoDocument = bsonReadDocument(ba);
			return result;
		}
		
		private static function bsonReadDocument(ba:ByteArray):MongoDocument {
			if (logBSON) log.debug("BSONDecoder::bsonReadDocument reading new document");
			// New document			
			var length:uint=ba.readUnsignedInt();
			return bsonReadElements(ba, false) as MongoDocument;
		}
		
		private static function bsonReadArray(ba:ByteArray, isArray:Boolean=false):Array {
			if (logBSON) log.debug("BSONDecoder::bsonReadDocument reading new array");
			// New document			
			var length:uint=ba.readUnsignedInt();
			return bsonReadElements(ba, true) as Array;
		}
		
		/**
		 * @return a MongoDocument if isArray is false, an Array else
		 */
		private static function bsonReadElements(ba:ByteArray, isArray:Boolean=false):Object {
			if (logBSON) log.debug("BSONDecoder::bsonReadDocument reading new elements");
			var result:Object;
			if (isArray) result = new Array();
			else result = new MongoDocument();
			// Element type
			var type:uint=ba.readByte();
			try {
				while (type != BSONEncoder.BSON_TERMINATOR) {
					if (logBSON) log.debug("BSONDecoder::bsonReadDocument reading new element type="+type);
					var attrName:String=bsonReadCString(ba);
					var attrValue:Object;
					switch (type) {
						case BSONEncoder.BSON_DOUBLE :
							if (isArray) result.push(ba.readDouble());
							else result.addKeyValuePair(attrName, ba.readDouble());
							break;
						case BSONEncoder.BSON_STRING :
							if (isArray) result.push(bsonReadString(ba));
							else result.addKeyValuePair(attrName, bsonReadString(ba));
							break;
						case BSONEncoder.BSON_JS :
							if (isArray) result.push(bsonReadJavaScriptCode(ba));
							else result.addKeyValuePair(attrName, bsonReadJavaScriptCode(ba));
							break;
						case BSONEncoder.BSON_DOCUMENT :
							var retDoc:MongoDocument = bsonReadDocument(ba);
							if (retDoc != null && retDoc.isDBRef()) {
								var dbref:DBRef = retDoc.toDBRef();
								if (isArray) result.push(dbref);
								else result.addKeyValuePair(attrName, dbref);
								if (logBSON) log.debug("bsonReadElements we have found a DBRef document :"+dbref);			
							}
							else if (isArray) result.push(retDoc);
							else result.addKeyValuePair(attrName, retDoc);
							break;
						case BSONEncoder.BSON_ARRAY :
							if (isArray) result.push(bsonReadArray(ba));
							else result.addKeyValuePair(attrName, bsonReadArray(ba));
							break;
						case BSONEncoder.BSON_OBJECTID :
							if (isArray) result.push(bsonReadObjectID(ba));
							else result.addKeyValuePair(attrName, bsonReadObjectID(ba));
							break;
						case BSONEncoder.BSON_BOOLEAN :
							var bool:Boolean = ba.readByte() == BSONEncoder.BSON_TERMINATOR ? false:true;
							if (isArray) result.push(bool);
							else result.addKeyValuePair(attrName, bool);
							break;
						case BSONEncoder.BSON_UTC :
							if (isArray) result.push(bsonReadUTC(ba));
							else result.addKeyValuePair(attrName, bsonReadUTC(ba));
							break;
						case BSONEncoder.BSON_NULL :
							if (isArray) result.push(null);
							else result.addKeyValuePair(attrName, null);
							break;
						case BSONEncoder.BSON_INT32 :
							if (isArray) result.push(ba.readInt());
							else result.addKeyValuePair(attrName, ba.readInt());
							break;
						case BSONEncoder.BSON_INT64 :
							if (isArray) result.push(bsonReadInt64(ba));
							else result.addKeyValuePair(attrName, bsonReadInt64(ba));
							break;
						default :
							var errMsg:String="BSONDecoder : TypeElement : '"+type+"' not implemented";
							log.error(errMsg);
							throw new ExceptionJMCNetMongoDB(errMsg);
					}
					type=ba.readByte();
				}
			} catch (e:ExceptionJMCNetMongoDB) {
				throw e;
			} catch (e1:Error) {
				errMsg = "Error decoding BSON near : '"+ObjectUtil.toString(result)+"' Error is :"+e1.message;
				log.error(errMsg);
				throw new ExceptionJMCNetMongoDB(errMsg);
			}
			
			if (logBSON) log.debug("BSONDecoder::bsonReadElements result="+result);
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
		
		private static function bsonReadInt64(ba:ByteArray):Number {
			var lowPos:uint  = ba.readUnsignedInt();
			var highPos:uint = ba.readUnsignedInt();
			var rep:Number   = (highPos * 256 * 256 * 256 * 256) + lowPos;
			return rep;
		}
		
		private static function bsonReadString(ba:ByteArray):String {
			var length:uint = ba.readInt();
			var res:String  = ba.readMultiByte(length - 1, "utf-8");
			ba.readByte(); 
			return res;
		}
		
		private static function bsonReadJavaScriptCode(ba:ByteArray):JavaScriptCode {
			var length:uint = ba.readInt();
			var code:String  = ba.readMultiByte(length - 1, "utf-8");
			ba.readByte();
			
			return new JavaScriptCode(code);
		}
		
		private static function bsonReadUTC(ba:ByteArray):Date
		{
			var ret:Date = new Date();
			ret.time = bsonReadInt64(ba);
			
			return ret;
		}
	}
}