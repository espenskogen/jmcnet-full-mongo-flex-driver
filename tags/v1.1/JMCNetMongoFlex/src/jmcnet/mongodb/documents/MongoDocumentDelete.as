package jmcnet.mongodb.documents
{
	import com.rubenswieringa.book.Book;
	
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;

	public class MongoDocumentDelete
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoDocumentDelete));
		
		private var _selector:MongoDocument = null;
		
		public function MongoDocumentDelete(selector:MongoDocument=null) {
			super();
			if (selector != null) if (MongoDocument.logDocument) log.debug("Creating Delete MongoDocument with selector="+selector.toString());
			_selector = selector;
			
		}
		
		public function addSelectorCriteria(key:String, value:Object):void {
			if (_selector == null) _selector = new MongoDocument();
			_selector.addKeyValuePair(key, value);
		}
		
		public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoDocumentDelete::toBSON");
			
			if (_selector == null) {
				_selector = new MongoDocument();
			}
			
			if (BSONEncoder.logBSON)  {
				if (_selector != null) log.debug("MongoDocumentDelete::toBSON selector="+_selector.toString());
				else log.debug("MongoDocumentDelete::toBSON selector=null");
			}
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			ba.writeBytes(BSONEncoder.bsonWriteDocument(_selector.table));
			
			if (BSONEncoder.logBSON) log.debug("MongoDocumentDelete::toBSON bson="+HelperByteArray.byteArrayToString(ba));
			return ba;
		}
	}
}