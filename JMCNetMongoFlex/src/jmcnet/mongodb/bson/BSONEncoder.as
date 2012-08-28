package jmcnet.mongodb.bson 
{

	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.describeType;
	
	import jmcnet.libcommun.communs.helpers.HelperClass;
	import jmcnet.libcommun.communs.structures.HashTable;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.documents.JavaScriptCode;
	import jmcnet.mongodb.documents.JavaScriptCodeScoped;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;
	
	import mx.utils.ObjectUtil;
	
	public class BSONEncoder {
		
		// the BSON types
		public static const BSON_TERMINATOR:uint = 0x00;
		public static const BSON_DOUBLE:uint     = 0x01;
		public static const BSON_STRING:uint     = 0x02;
		public static const BSON_DOCUMENT:uint   = 0x03;
		public static const BSON_ARRAY:uint      = 0x04;
		public static const BSON_BINARY:uint     = 0x05;
		// 0x06 is deprecated
		public static const BSON_OBJECTID:uint   = 0x07;
		public static const BSON_BOOLEAN:uint    = 0x08;
		public static const BSON_UTC:uint        = 0x09;
		public static const BSON_NULL:uint       = 0x0a;
		public static const BSON_REGEXP : uint = 0x0b;
		// 0x0c is deprecated
		public static const BSON_JS : uint = 0x0d;
		// public static const BSON_SYMBOL : uint = 0x0e;
		public static const BSON_SCOPEDJS : uint = 0x0f;
		public static const BSON_INT32:uint      = 0x10;
		// public static const BSON_TIMESTAMP : uint = 0x11;
		public static const BSON_INT64:uint      = 0x12;
		
		// public static const BSON_MAX : uint = 0x7f;
		// public static const BSON_MIN : uint = 0xff;
		
		public static const BSON_FALSE: uint=0x00;
		public static const BSON_TRUE: uint=0x01;
		
		public static var logBSON:Boolean = false;
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(BSONEncoder);
		
		public static function encodeObjectToBSON(obj:Object):ByteArray {
			if (logBSON) log.info("Calling encodeObjectToBSON obj="+ObjectUtil.toString(obj));
			if (obj == null) return null;
			var result:ByteArray = bsonWriteDocument(obj);
			
			if (logBSON) log.debug("BSONEncoder::encodeObjectToBSON bson="+HelperByteArray.bsonDocumentToReadableString(result));
			if (logBSON) log.info("End of encodeObjectToBSON result="+HelperByteArray.byteArrayToString(result));
			return result;
		}
		
		/**
		 * Converts a document to it's BSON string equivalent.
		 *
		 * @param value The value to convert.  Could be any 
		 *		type (object, number, array, etc)
		 */
		public static function bsonWriteDocument( value:Object, rootAttrName:String=null):ByteArray {
			if (logBSON) log.debug("Calling bsonWriteDocument value="+ObjectUtil.toString(value)+" rootAttrName="+rootAttrName);
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			ba.writeUnsignedInt(0); // Size of doc
			
			if (value != null) ba.writeBytes(bsonWriteElements(value, rootAttrName));
			
			// Ecriture du 0 terminal
			ba.writeByte(BSON_TERMINATOR);
			
			// Ecriture de la taille du doc
			ba.position = 0;
			ba.writeUnsignedInt(ba.length);
			if (logBSON) log.debug("End of BSONEncoder::bsonWriteDocument bson="+HelperByteArray.byteArrayToString(ba));
			
            return ba;
		}
		
		/**
		 * Converts a value to it's BSON string equivalent.
		 *
		 * @param value The value to convert.  Could be any 
		 *		type (object, number, array, etc)
		 */
		public static function bsonWriteElements( value:Object, attrName:String=null ):ByteArray {
			if (logBSON) log.debug("Calling bsonWriteElements value="+ObjectUtil.toString(value)+" attrName="+attrName);
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			// determine what value is and convert it based on it's type
			if (value == null) {
				if (logBSON) log.debug("Encoding of a null value");
				ba.writeByte(BSONEncoder.BSON_NULL);
				writeAttrName(attrName, ba);
			}
			else if ( value is String ) {
				if (logBSON) log.debug("Encoding of String");
				ba.writeBytes(convertUTF8String(value as String, attrName));
			} else if ( value is int || value is uint ) {
				if (logBSON) log.debug("Encoding of Int");
				ba.writeBytes(convertInt(value as int, attrName));
			} else if ( value is Number ) {
				if (logBSON) log.debug("Encoding of Number");
				ba.writeBytes(convertNumber(value as Number, attrName));
			} else if ( value is Boolean ) {
				if (logBSON) log.debug("Encoding of Boolean");
				ba.writeBytes(convertBoolean(value as Boolean, attrName));
			} else if ( value is Date ) {
				if (logBSON) log.debug("Encodage d'une Date");
				ba.writeBytes(convertDate(value as Date, attrName));
			} else if ( value is ObjectID ) {
				if (logBSON) log.debug("Encoding of ObjectID");
				ba.writeBytes(convertObjectID(value as ObjectID, attrName));
			} else if ( value is Array ) {
				if (logBSON) log.debug("Encoding of Array");
				ba.writeBytes(convertArray(value as Array, attrName));
			} else if ( value is MongoDocument && value != null ) {
				if (logBSON) log.debug("Encoding of MongoDocument");
				ba.writeBytes(convertMongoDocument(value as MongoDocument, attrName));
			} else if ( value is HashTable && value != null ) {
				if (logBSON) log.debug("Encodage d'une Hashtable");
				ba.writeBytes(hashtableToString(value as HashTable));
			} else if ( value is JavaScriptCodeScoped && value != null ) {
				if (logBSON) log.debug("Encoding of JavaScriptCodeScoped");
				ba.writeBytes(convertJavaScriptCodeScoped(value as JavaScriptCodeScoped, attrName));
			} else if ( value is JavaScriptCode && value != null ) {
				if (logBSON) log.debug("Encoding of JavaScriptCode");
				ba.writeBytes(convertJavaScriptCode(value as JavaScriptCode, attrName));
			} else if ( value is Object && value != null ) {
				if (logBSON) log.debug("Encoding of Object");
				ba.writeBytes(convertObject(value, attrName));
			}
			else {
				log.warn("Warning : type not known. No encoding for type :"+ObjectUtil.toString(value));
			}
			if (logBSON) log.debug("BSONEncoder::convertElement bson="+HelperByteArray.byteArrayToString(ba));
			return ba;
		}
		
		/**
		 * Converts a value to it's BSON string equivalent.
		 *
		 * @param value The value to convert.  Could be any 
		 *		type (object, number, array, etc)
		 */
		public static function convertUTF8String( value:String, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertUTF8String value="+ObjectUtil.toString(value)+" attrName="+attrName);
			// AttrName cannot be null there
//			if (attrName == null) throw ExceptionJMCNetMongoDB("BSONEncoder : String value '"+value+"' must have an attribute name");
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeByte(BSON_STRING);
			writeAttrName(attrName, ba);
				
			ba.writeBytes(writeString(value, true));
						
			if (logBSON) log.debug("End of convertUTF8String result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		private static function writeString(value:String, escape:Boolean=true):ByteArray {
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			ba.writeUnsignedInt(0);
			
			// escape the string so it's formatted correctly
			if (value != null) {
				var s:String = value;
				if (escape) s=escapeString( value );
				
				ba.writeMultiByte(s, "utf-8");
			}
			ba.writeByte(BSON_TERMINATOR);
			
			ba.position = 0;
			ba.writeUnsignedInt(ba.length - 4);
			
			return ba;
		}
		
		private static function writeCode_w_s(code:String, vars:MongoDocument):ByteArray {
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			ba.writeUnsignedInt(0);

			ba.writeBytes(writeString(code, false));
			ba.writeBytes(bsonWriteDocument(vars));
			
			ba.position = 0;
			ba.writeUnsignedInt(ba.length);
			
			return ba;
		}
		
		/**
		 * Converts a JavaScriptCode value to it's BSON string equivalent.
		 *
		 * @param value The value to convert.  Could be any 
		 *		type (object, number, array, etc)
		 */
		public static function convertJavaScriptCode( value:JavaScriptCode, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertJavaScriptCode value="+value+" attrName="+attrName);
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeByte(BSON_JS);
			writeAttrName(attrName, ba);
			
			// The JS Code
			ba.writeBytes(writeString(value.code,false));
			
			if (logBSON) log.debug("End of convertJavaScriptCode result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		/**
		 * Converts a JavaScriptCode value to it's BSON string equivalent.
		 *
		 * @param value The value to convert.  Could be any 
		 *		type (object, number, array, etc)
		 */
		public static function convertJavaScriptCodeScoped( value:JavaScriptCodeScoped, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertJavaScriptCodeScoped value="+value+" attrName="+attrName);
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeByte(BSON_SCOPEDJS);
			writeAttrName(attrName, ba);
			
			// The code_w_s Code
			ba.writeBytes(writeCode_w_s(value.code, value.vars));
			
			if (logBSON) log.debug("End of convertJavaScriptCode result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function convertNumber( value:Number, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertNumber value="+ObjectUtil.toString(value)+" attrName="+attrName);
			// AttrName cannot be null there
//			if (attrName == null) throw ExceptionJMCNetMongoDB("BSONEncoder : Number value '"+value+"' must have an attribute name");
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			// only encode numbers that finate
			if (isFinite( value )) {
				ba.writeByte(BSON_DOUBLE);
				writeAttrName(attrName, ba);
				ba.writeDouble(value);
			}
			else {
				// write null attribute if not finite value
				ba.writeByte(BSON_NULL);
				writeAttrName(attrName, ba);
			}
			if (logBSON) log.debug("End of convertNumber result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function convertInt( value:int, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertInt value="+value+" attrName="+attrName);
			// AttrName cannot be null there
//			if (attrName == null) throw ExceptionJMCNetMongoDB("BSONEncoder : Int value '"+value+"' must have an attribute name");
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeByte(BSON_INT32);
			writeAttrName(attrName, ba);
			ba.writeInt(value);
			if (logBSON) log.debug("End of convertInt result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function convertBoolean( value:Boolean, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertBoolean value="+ObjectUtil.toString(value)+" attrName="+attrName);
			// AttrName cannot be null there
//			if (attrName == null) throw ExceptionJMCNetMongoDB("BSONEncoder : Boolean value '"+value+"' must have an attribute name");
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeByte(BSON_BOOLEAN);
			writeAttrName(attrName, ba);
			
			if (value) ba.writeByte(BSON_TRUE);
			else ba.writeByte(BSON_FALSE);
			
			if (logBSON) log.debug("End of convertBoolean result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function convertDate( value:Date, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertDate value="+ObjectUtil.toString(value)+" attrName="+attrName);
			// AttrName cannot be null there
//			if (attrName == null) throw ExceptionJMCNetMongoDB("BSONEncoder : Date value '"+value+"' must have an attribute name");
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeByte(BSON_UTC);
			writeAttrName(attrName, ba);
			
			// Write in int64 the number of millisecond since beginnig of unix
			var n:Number = (value as Date).getTime();
			var i1:uint = n / (256 * 256 * 256 * 256);
			var i2:uint = n % (256 * 256 * 256 * 256);
			
			if (logBSON) log.debug("convertDate n="+n+" i1="+i1+" i2="+i2);
			
			ba.writeUnsignedInt(i2);
			ba.writeUnsignedInt(i1);
			if (logBSON) log.debug("End of convertDate result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function convertObjectID( value:ObjectID, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertObjectID value="+ObjectUtil.toString(value)+" attrName="+attrName);
			// AttrName cannot be null there
			if (attrName == null) throw ExceptionJMCNetMongoDB("BSONEncoder : ObjectID value '"+value+"' must have an attribute name");
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeByte(BSON_OBJECTID);
			writeAttrName(attrName, ba);
			
			// Write 12 Bytes
			ba.writeBytes(value.getAsBytes(), 0, 12);
			
			if (logBSON) log.debug("End of convertObjectID result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function convertArray( value:Array, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertArray value="+ObjectUtil.toString(value)+" attrName="+attrName);
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			var attributes:HashTable = new HashTable();
			for ( var i:int = 0; i < value.length; i++ ) {
				attributes.addItem(""+i, value[i]);
			}

			ba.writeByte(BSON_ARRAY);
			writeAttrName(attrName, ba);
			// We write the hashtable as a document
			ba.writeBytes(bsonWriteDocument(attributes));
			
			if (logBSON) log.debug("Fin de convertArray result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
				
		public static function convertObject( value:Object, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertObject value="+ObjectUtil.toString(value)+" attrName="+attrName);
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;

			var attributes:HashTable = HelperClass.getObjectAttributes(value);

			if (attrName != null) {
				ba.writeByte(BSON_DOCUMENT);
				writeAttrName(attrName, ba);
				ba.writeBytes(bsonWriteDocument(attributes));
			}
			else {
				ba.writeBytes(bsonWriteElements(attributes));
			}
			
			if (logBSON) log.debug("End of convertObject result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function convertMongoDocument( value:MongoDocument, attrName:String ):ByteArray {
			if (logBSON) log.debug("Calling convertMongoDocument value="+ObjectUtil.toString(value)+" attrName="+attrName);
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			if (attrName != null) {
				ba.writeByte(BSON_DOCUMENT);
				writeAttrName(attrName, ba);
				ba.writeBytes(bsonWriteDocument(value.table));
			}
			else {
				ba.writeBytes(bsonWriteElements(value.table));
			}
			
			if (logBSON) log.debug("End of convertMongoDocument result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		public static function writeAttrName(attrName:String, ba:ByteArray):void {
			ba.writeMultiByte(attrName == null ? "":attrName, "utf-8");
			ba.writeByte(BSON_TERMINATOR);
		}
		
		public static function hashtableToString( value:HashTable):ByteArray {
			if (logBSON) log.debug("Calling convertHashtable value="+ObjectUtil.toString(value));
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			// loop over the elements in the hashtable and add their converted
			// values to the string
			for each ( var key:String in value.getAllKeys() ) {
				// convert the value to a string
				ba.writeBytes(bsonWriteElements( value.getItem(key), key ));	
			}
			
			if (logBSON) log.debug("End of convertHashtable result='"+HelperByteArray.byteArrayToString(ba)+"'");
			return ba;
		}
		
		/**
		 * Escapes a string accoding to the JSON specification.
		 *
		 * @param str The string to be escaped
		 * @return The string with escaped special characters
		 * 		according to the JSON specification
		 */
		public static function escapeString( str:String ):String {
			// create a string to store the string's jsonstring value
			var s:String = "";
			// current character in the string we're processing
			var ch:String;
			// store the length in a local variable to reduce lookups
			var len:Number = str.length;
			
			// loop over all of the characters in the string
			for ( var i:int = 0; i < len; i++ ) {
			
				// examine the character to determine if we have to escape it
				ch = str.charAt( i );
				switch ( ch ) {
				
					case '"':	// quotation mark
						s += "\\\"";
						break;
						
					//case '/':	// solidus
					//	s += "\\/";
					//	break;
						
					case '\\':	// reverse solidus
						s += "\\\\";
						break;
						
					case '\b':	// bell
						s += "\\b";
						break;
						
					case '\f':	// form feed
						s += "\\f";
						break;
						
					case '\n':	// newline
						s += "\\n";
						break;
						
					case '\r':	// carriage return
						s += "\\r";
						break;
						
					case '\t':	// horizontal tab
						s += "\\t";
						break;
						
					default:	// everything else
						
						// check for a control character and escape as unicode
						if ( ch < ' ' ) {
							// get the hex digit(s) of the character (either 1 or 2 digits)
							var hexCode:String = ch.charCodeAt( 0 ).toString( 16 );
							
							// ensure that there are 4 digits by adjusting
							// the # of zeros accordingly.
							var zeroPad:String = hexCode.length == 2 ? "00" : "000";
							
							// create the unicode escape sequence with 4 hex digits
							s += "\\u" + zeroPad + hexCode;
						} else {
						
							// no need to do any special encoding, just pass-through
							s += ch;
							
						}
				}	// end switch
				
			}	// end for loop
						
			return s;
		}
	}
}
