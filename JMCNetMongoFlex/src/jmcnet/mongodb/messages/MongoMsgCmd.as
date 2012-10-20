package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;
	
	import mx.states.OverrideBase;

	/**
	 * A generic Query message command.
	 */
	public class MongoMsgCmd extends MongoMsgAbstract
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoMsgCmd);
		
		private var _cmd:MongoDocument=null;
		
		public function MongoMsgCmd(dbName:String, collectionName:String="$cmd")
		{
			super(dbName, collectionName, MongoMsgHeader.OP_QUERY);
		}
		
		public function get cmd():MongoDocument	{	return _cmd; }
		public function set cmd(value:MongoDocument):void{ _cmd = value; }

		override public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling toBSON");
			
			// There must one or mode documents to insert
			var msg:ByteArray = new ByteArray();
			msg.endian = Endian.LITTLE_ENDIAN;
			
			//header
			msg.writeBytes(getHeaderBSON());
			// Flags
			msg.writeUnsignedInt(0);
			
			// Full collection name db.collectionName
			writeFullCollectionName(msg);
			
			// NumberToSkip
			msg.writeUnsignedInt(0);
			// Number to return -> -1
			msg.writeInt(-1);
			
			// If there is no query, assume we want all docs
			if (_cmd == null) {
				var errorMsg:String="A cmd message cannot be empty";
				log.error(errorMsg);
				throw new ExceptionJMCNetMongoDB(errorMsg);
			}
			
			msg.writeBytes( _cmd.toBSON());
			
			// Message length at beginning
			writeMsgLength(msg);
			
			if (BSONEncoder.logBSON) log.debug("EndOf toBSON bsonMsg="+HelperByteArray.byteArrayToString(msg));
			
			return msg;
		}
		
		override public function get needResponse():Boolean { return true;}
		
		override public function toString():String {
			return "[MongoMsgCmd : cmd="+cmd+" header=["+header+"]]";
		}
	}
}