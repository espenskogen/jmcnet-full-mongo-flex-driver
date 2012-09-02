package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocumentKillCursors;

	/**
	 * A generic Query message command.
	 */
	public class MongoMsgKillCursors extends MongoMsgAbstract
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoMsgKillCursors));
		
		private var _docKillCursors:MongoDocumentKillCursors;
		
		public function MongoMsgKillCursors(docKillCursors:MongoDocumentKillCursors)
		{
			super(null, null, MongoMsgHeader.OP_KILL_CURSORS);
			_docKillCursors = docKillCursors;
		}
		
		override public function toBSON():ByteArray {
			if (BSONEncoder.logBSON) log.debug("Calling MongoMsgKillCursors::toBSON");
			
			// There must one or mode documents to insert
			var msg:ByteArray = new ByteArray();
			msg.endian = Endian.LITTLE_ENDIAN;
			
			//header
			msg.writeBytes(getHeaderBSON());
			// ZERO
			msg.writeUnsignedInt(0);
			
			// CursorIDs
			msg.writeBytes(_docKillCursors.toBSON());
			
			// Message length at beginning
			writeMsgLength(msg);
			
			if (BSONEncoder.logBSON) log.evt("MongoMsgKillCursors::toBSON bsonMsg="+HelperByteArray.byteArrayToString(msg));
			
			return msg;
		}
		
		override public function toString():String {
			return "[MongoMsgKillCursors : document="+(_docKillCursors != null ? _docKillCursors.toString():"empty")+" header=["+(header != null ? header.toString():"null")+"]]";
		}
	}
}