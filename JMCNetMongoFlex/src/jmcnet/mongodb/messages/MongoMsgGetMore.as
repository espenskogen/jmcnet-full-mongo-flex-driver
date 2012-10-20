package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.Cursor;
	
	/**
	 * A generic Query message command.
	 */
	public class MongoMsgGetMore extends MongoMsgAbstract
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoMsgGetMore));
		
		private var _numberToReturn:int=0;
		private var _cursorID:Cursor=new Cursor(0, 0);
		
		public function MongoMsgGetMore(dbName:String, collectionName:String, cursorID:Cursor, numberToReturn:int=0)
		{
			super(dbName, collectionName, MongoMsgHeader.OP_GETMORE);
			_cursorID = cursorID;
			_numberToReturn = numberToReturn;
		}
		
		override public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoMsgGetMore::toBSON cursorID="+_cursorID+" numberToRetun="+_numberToReturn);
			
			// There must one or mode documents to insert
			var msg:ByteArray = new ByteArray();
			msg.endian = Endian.LITTLE_ENDIAN;
			
			//header
			msg.writeBytes(getHeaderBSON());
			// ZERO
			msg.writeUnsignedInt(0);
			
			// Full collection name db.collectionName
			writeFullCollectionName(msg);
			
			// NumberToReturn
			msg.writeInt(_numberToReturn);
			
			// CursorID
			msg.writeBytes(_cursorID.toBSON());
			
			// Message length at beginning
			writeMsgLength(msg);
			
			if (BSONEncoder.logBSON) log.debug("MongoMsgGetMore::toBSON bsonMsg="+HelperByteArray.byteArrayToString(msg));
			
			return msg;
		}
		
		override public function get needResponse():Boolean { return true;}
		
		override public function toString():String {
			return "[MongoMsgGetMore : cursorID="+_cursorID+" header=["+header+"]]";
		}
	}
	
	
}