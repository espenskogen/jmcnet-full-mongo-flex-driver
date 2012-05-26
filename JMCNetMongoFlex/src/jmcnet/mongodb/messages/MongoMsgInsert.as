package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;

	public class MongoMsgInsert extends MongoMsgAbstract
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoMsgInsert));
		
		private var _documents:Array = new Array();
		private var _continueOnError:Boolean=true;
		
		public function MongoMsgInsert(dbName:String, collectionName:String, continueOnError:Boolean=true) {
			super(dbName, collectionName, MongoMsgHeader.OP_INSERT);
			_continueOnError = continueOnError;
		}
		
		public function addDocument(document:Object):void {
			_documents.push(document);
		}
		
		override public function toBSON():ByteArray {
			// There must one or mode documents to insert
			if (_documents.length <= 0) {
				var errMsg:String="MongoDBDriverException : there must be at least one document to insert";
				log.error(errMsg);
				throw new ExceptionJMCNetMongoDB(errMsg);
			}
			
			var msg:ByteArray = new ByteArray();
			msg.endian = Endian.LITTLE_ENDIAN;
			
			//header
			msg.writeBytes(getHeaderBSON());
			// Flags
			if (_continueOnError) {
				msg.writeUnsignedInt(1);
			}
			else {
				msg.writeUnsignedInt(0);
			}
			// Full collection name db.collectionName
			writeFullCollectionName(msg);
			
			for each (var document:Object in _documents) {
				// If document does have a ObjectID property and is not set, set it
				if (document.hasOwnProperty("_id") && document["_id"] == null) {
					log.debug("Generating a ObjectID for document"); 
					document["_id"] = new ObjectID();
				}
				var doc:ByteArray = BSONEncoder.encodeObjectToBSON(document);
				msg.writeBytes(doc);
			}
			
			// Message length at beginning
			writeMsgLength(msg);
			
			if (BSONEncoder.logBSON) log.debug("MongoMsgInsert::toBSON bsonMsg="+HelperByteArray.byteArrayToString(msg));
			
			return msg;
		}
	}
}