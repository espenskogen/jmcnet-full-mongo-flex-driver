package jmcnet.mongodb.documents
{
	import com.rubenswieringa.book.Book;
	
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;

	public class MongoDocumentQuery
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoDocumentQuery);
		
		private var _query:MongoDocument = null;
		private var _orderBy:MongoDocument = null;
		private var _flags:uint=0;
		
		public function MongoDocumentQuery(query:MongoDocument=null, orderBy:MongoDocument=null) {
			super();
			if (query != null) if (MongoDocument.logDocument) log.debug("Creating MongoDocument with query="+query.toString());
			_query = query;
			_orderBy = orderBy;
		}
		
		public function addQueryCriteria(key:String, value:Object):void {
			if (_query == null) _query = new MongoDocument();
			_query.addKeyValuePair(key, value);
		}
		
		public function addDocumentCriteria(doc:MongoDocument):void {
			if (_query == null) _query = new MongoDocument();
			for each (var key:String in doc.getKeys()) {
				_query.addKeyValuePair(key, doc.getValue(key));
			}
		}
		
		public function addOrderByCriteria(key:String, ascending:Boolean=true):void {
			if (_orderBy == null) _orderBy = new MongoDocument();
			_orderBy.addKeyValuePair(key, ascending ? 1:-1);
		}
		
		public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoDocumentQuery::toBSON");
			if (_query == null) _query = new MongoDocument();
			
			if (BSONEncoder.logBSON) {
				log.debug("MongoDocumentQuery::toBSON query="+_query.toString());
				if (_orderBy != null) log.debug("MongoDocumentQuery::toBSON orderBy="+_orderBy.toString());
				else log.debug("MongoDocumentQuery::toBSON orderBy=null");
			}
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			var g:MongoDocument = new MongoDocument();
			g.addKeyValuePair("$query", _query);
			if (_orderBy != null) {
				g.addKeyValuePair("$orderby",_orderBy);
			}
			
			ba.writeBytes(BSONEncoder.bsonWriteDocument(g));
			
			if (BSONEncoder.logBSON) log.debug("MongoDocumentQuery::toBSON bson="+HelperByteArray.byteArrayToString(ba));
			return ba;
		}
		
		public function toString():String {
			var ret:String="{ ";
			if (_query != null) ret += "query : "+_query.toString()+" ";
			if (_orderBy != null) ret += "orberby : "+_orderBy.toString()+" ";
			ret += " }";
			
			return ret;
		}
	}
}