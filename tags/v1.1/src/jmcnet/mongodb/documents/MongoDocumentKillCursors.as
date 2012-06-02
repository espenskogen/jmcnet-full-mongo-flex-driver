package jmcnet.mongodb.documents
{
	import com.rubenswieringa.book.Book;
	
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;

	public class MongoDocumentKillCursors
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoDocumentKillCursors));
		
		private var _lstCursorsID:Array = new Array();
		
		public function MongoDocumentKillCursors(cursors:Array=null) {
			super();
			if (cursors != null) {
				for each (var cursor:Cursor in cursors) {
					addCursorID(cursor);
				}
			}
		}
		
		public function addCursorID(cursorID:Cursor):void {
			_lstCursorsID.push(cursorID);
		}
		
		public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoDocumentKillCursors::toBSON");
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			
			// nb cursors
			ba.writeUnsignedInt(_lstCursorsID.length);
			
			// Cursors
			for each (var cursorID:Cursor in _lstCursorsID) {
				ba.writeBytes(cursorID.toBSON());
			}
			
			if (BSONEncoder.logBSON) log.debug("MongoDocumentKillCursors::toBSON bson="+HelperByteArray.byteArrayToString(ba));
			return ba;
		}
	}
}