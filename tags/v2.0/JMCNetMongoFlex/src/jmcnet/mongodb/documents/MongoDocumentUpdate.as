package jmcnet.mongodb.documents
{
	import com.rubenswieringa.book.Book;
	
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;

	public class MongoDocumentUpdate
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoDocumentUpdate);
		
		private var _update:MongoDocument = null;
		private var _selector:MongoDocument = null;
		
		public function MongoDocumentUpdate(selector:MongoDocument=null, update:MongoDocument=null) {
			super();
			if (update != null) if (MongoDocument.logDocument) log.debug("Creating MongoDocument with update="+update.toString());
			_update = update;
			_selector = selector;
			
		}
		
		public function addUpdateCriteria(key:String, value:Object):void {
			if (_update == null) _update = new MongoDocument();
			_update.addKeyValuePair(key, value);
		}
		
		public function addSelectorCriteria(key:String, value:Object):void {
			if (_selector == null) _selector = new MongoDocument();
			_selector.addKeyValuePair(key, value);
		}
		
		public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoDocumentUpdate::toBSON");
			if (_update == null) _update = new MongoDocument();
			
			if (BSONEncoder.logBSON) {
				log.debug("MongoDocumentUpdate::toBSON update="+_update.toString());
				if (_selector != null) log.debug("MongoDocumentUpdate::toBSON selector="+_selector.toString());
				else log.debug("MongoDocumentUpdate::toBSON selector=null");
			}
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			if (_selector == null) {
				_selector = new MongoDocument();
			}
			ba.writeBytes(BSONEncoder.bsonWriteDocument(_selector.table));
			ba.writeBytes(BSONEncoder.bsonWriteDocument(_update.table));
			
			if (BSONEncoder.logBSON) log.debug("MongoDocumentUpdate::toBSON bson="+HelperByteArray.byteArrayToString(ba));
			return ba;
		}
		
		public function toString():String {
			var ret:String="{ ";
			if (_update != null) ret += "update : "+_update.toString()+" ";
			if (_selector != null) ret += "selector : "+_selector.toString()+" ";
			ret += " }";
			
			return ret;
		}
	}
}