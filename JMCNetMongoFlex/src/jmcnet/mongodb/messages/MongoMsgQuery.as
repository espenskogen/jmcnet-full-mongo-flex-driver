package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	
	import mx.states.OverrideBase;

	/**
	 * A generic Query message command.
	 */
	public class MongoMsgQuery extends MongoMsgAbstract
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoMsgQuery);
		
		private var _flags:uint=0;
		private var _numberToSkip:uint=0;
		private var _numberToReturn:int=0;
		private var _query:MongoDocumentQuery=null;
		private var _returnFieldsSelector:MongoDocument=null;
		
		public function MongoMsgQuery(dbName:String, collectionName:String, numberToSkip:uint=0, numberToReturn:int=0, tailableCursor:Boolean=false, slaveOk:Boolean=false, noCursorTimeout:Boolean=false, awaitData:Boolean=false, exhaust:Boolean=false, partial:Boolean=false)
		{
			super(dbName, collectionName, MongoMsgHeader.OP_QUERY);
			_numberToSkip = numberToSkip;
			_numberToReturn = numberToReturn;
			_flags = tailableCursor ? 2:0 +
					slaveOk ? 4:0 +
					noCursorTimeout ? 16:0 +
					awaitData ? 32:0 +
					exhaust ? 64:0 +
					partial ? 128:0;
		}
		
		public function get query():MongoDocumentQuery	{	return _query; }
		public function set query(value:MongoDocumentQuery):void{ _query = value; }

		public function get returnFieldsSelector():MongoDocument{	return _returnFieldsSelector;	}
		public function set returnFieldsSelector(value:MongoDocument):void	{	_returnFieldsSelector = value;	}

		override public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling toBSON");
			
			// There must one or mode documents to insert
			var msg:ByteArray = new ByteArray();
			msg.endian = Endian.LITTLE_ENDIAN;
			
			//header
			msg.writeBytes(getHeaderBSON());
			// Flags
			msg.writeUnsignedInt(_flags);
			
			// Full collection name db.collectionName
			writeFullCollectionName(msg);
			
			// NumberToSkip
			msg.writeUnsignedInt(_numberToSkip);
			msg.writeInt(_numberToReturn);
			
			// If there is no query, assume we want all docs
			if (_query == null) {
				_query = new MongoDocumentQuery();
			}
			
			msg.writeBytes( _query.toBSON());
			
			// Write returnFieldsSelector if there is one
			if (_returnFieldsSelector != null) {
				msg.writeBytes(_returnFieldsSelector.toBSON());
			}
			
			// Message length at beginning
			writeMsgLength(msg);
			
			if (BSONEncoder.logBSON) log.debug("MongoMsgQuery::toBSON bsonMsg="+HelperByteArray.byteArrayToString(msg));
			
			return msg;
		}
		
		override public function get needResponse():Boolean { return true;}
		
		override public function toString():String {
			var msg:String="[MongoMsgQuery : query="+(query != null ? query.toString():"null")+" header=["+(header != null ? header.toString():"null")+"]]";
			return msg;
		}
	}
}