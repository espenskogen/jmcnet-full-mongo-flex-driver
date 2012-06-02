package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;

	/**
	 * Handle Mongo's messages headers. If requestID is not set, an automatic value is generated (a sequence value)
	 */
	public class MongoMsgHeader
	{
		private var _messageLength:uint=0;
		private var _requestID:uint=0;
		private var _responseTo:uint=0;
		private var _opCode:uint=0;
		
		public static var requestIDCounter:uint=0; // The requestID value
		
		public static const OP_REPLY:uint=1; // 	Reply to a client request. responseTo is set
		public static const OP_MSG:uint=1000 // 	generic msg command followed by a string
		public static const OP_UPDATE:uint=2001 // 	update document
		public static const OP_INSERT:uint=2002 // 	insert new document
		public static const RESERVED:uint=2003 // 	formerly used for OP_GET_BY_OID
		public static const OP_QUERY:uint=2004 // 	query a collection
		public static const OP_GETMORE:uint=2005 // 	Get more data from a query. See Cursors
		public static const OP_DELETE:uint=2006 // 	Delete documents
		public static const OP_KILL_CURSORS:uint=2007 // 	Tell database client is done with a cursor
			
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoMsgHeader));
		
		public function MongoMsgHeader(opCode:uint=0) {
			this._opCode = opCode;
		}
		
		protected function incRequestIDCounter():void { requestIDCounter++;}
		
		public function toBSON():ByteArray {
			if (_opCode == 0) {
				log.warn("Warning : MongoMsgHeader's opCode is not set.");
			}
			
			if (_requestID == 0) {
				_requestID = requestIDCounter++;
				if (BSONEncoder.logBSON) log.info("Setting MongoMsgHeader's requestID to "+_requestID);
			}
			
			var ba:ByteArray = new ByteArray();
			ba.endian = Endian.LITTLE_ENDIAN;
			ba.writeUnsignedInt(_messageLength);
			ba.writeUnsignedInt(_requestID);
			ba.writeUnsignedInt(_responseTo);
			ba.writeUnsignedInt(_opCode);
			
			if (BSONEncoder.logBSON) log.debug("MongoMsgHeader byteArray is : "+HelperByteArray.byteArrayToString(ba));
				
			return ba;
		}
		
		public function fromBSON(length:uint, bson:ByteArray):void {
			this._messageLength = length;
			this._requestID = bson.readUnsignedInt();
			this._responseTo = bson.readUnsignedInt();
			this._opCode = bson.readUnsignedInt();
			if (BSONEncoder.logBSON) log.debug("MongoMsgHeader::fromBSON messageLength="+_messageLength+" requestID="+_requestID+" responseTo="+_responseTo+" opCode="+_opCode);
		}

		public function get requestID():uint { return _requestID; }
		public function set requestID(value:uint):void {	_requestID = value;	}
		public function get responseTo():uint{	return _responseTo;}
		public function set responseTo(value:uint):void { _responseTo = value;	}
		public function get opCode():uint { return _opCode;}
		public function set opCode(value:uint):void	{_opCode = value;}
		public function set messageLength(msgLength:uint):void { this._messageLength = msgLength; }
		public function get messageLength():uint { return _messageLength;}
	}
}