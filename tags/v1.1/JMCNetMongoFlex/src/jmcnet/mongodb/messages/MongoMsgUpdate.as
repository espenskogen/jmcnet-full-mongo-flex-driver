package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocumentUpdate;

	/**
	 * A generic Query message command.
	 */
	public class MongoMsgUpdate extends MongoMsgAbstract
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoMsgUpdate));
		
		private var _update:MongoDocumentUpdate=null;
		private var _flags:uint=0;
		
		public function MongoMsgUpdate(dbName:String, collectionName:String, update:MongoDocumentUpdate=null, upsert:Boolean=false, multiUpdate:Boolean=false) {
			super(dbName, collectionName, MongoMsgHeader.OP_UPDATE);
			_update = update;
			setFlags(upsert, multiUpdate);
		}
		
		public function setFlags(upsert:Boolean, multiUpdate:Boolean):void {
			_flags = (upsert ? 1:0) + (multiUpdate ? 2:0);
		}
		
		public function isUpsert():Boolean { return _flags & 1 != 0 ? true:false ;}
		public function isMultiUpdate():Boolean { return _flags & 2 != 0 ? true:false;}
		
		public function get update():MongoDocumentUpdate	{	return _update; }
		public function set update(value:MongoDocumentUpdate):void{ _update = value; }

		override public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoMsgUpdate::toBSON");
			
			// There must one or mode documents to insert
			var msg:ByteArray = new ByteArray();
			msg.endian = Endian.LITTLE_ENDIAN;
			
			//header
			msg.writeBytes(getHeaderBSON());
			// ZERO
			msg.writeUnsignedInt(0);
			// Full collection name db.collectionName
			writeFullCollectionName(msg);
			// Flags
			msg.writeUnsignedInt(_flags);
			
			// Write update messages (selector and update)
			msg.writeBytes( _update.toBSON());
			
			// Message length at beginning
			writeMsgLength(msg);
			
			if (BSONEncoder.logBSON) log.debug("MongoMsgUpdate::toBSON bsonMsg="+HelperByteArray.byteArrayToString(msg));
			
			return msg;
		}		
	}
}