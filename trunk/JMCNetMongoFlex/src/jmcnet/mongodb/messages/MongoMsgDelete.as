package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocumentDelete;

	/**
	 * A generic Query message command.
	 */
	public class MongoMsgDelete extends MongoMsgAbstract
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoMsgDelete));
		
		private var _deleteDoc:MongoDocumentDelete=null;
		private var _flags:uint=0;
		
		public function MongoMsgDelete(dbName:String, collectionName:String, deleteDoc:MongoDocumentDelete=null, singleRemove:Boolean=false) {
			super(dbName, collectionName, MongoMsgHeader.OP_DELETE);
			_deleteDoc = deleteDoc;
			setFlags(singleRemove);
		}
		
		public function setFlags(singleRemove:Boolean):void {
			_flags = (singleRemove ? 1:0);
		}
		
		public function isSingleRemove():Boolean { return _flags & 1 != 0 ? true:false;}
		
		public function get deleteDoc():MongoDocumentDelete	{	return _deleteDoc; }
		public function set deleteDoc(value:MongoDocumentDelete):void{ _deleteDoc = value; }

		override public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoMsgDelete::toBSON");
			
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
			
			// Write delete messages selector
			msg.writeBytes( _deleteDoc.toBSON());
			
			// Message length at beginning
			writeMsgLength(msg);
			
			if (BSONEncoder.logBSON) log.debug("MongoMsgDelete::toBSON bsonMsg="+HelperByteArray.byteArrayToString(msg));
			
			return msg;
		}
		
		override public function toString():String {
			return "[MongoMsgDelete : doc="+(_deleteDoc != null ? _deleteDoc.toString():"null")+" header=["+(header != null ? header.toString():"null")+"]]";
		}
	}
}