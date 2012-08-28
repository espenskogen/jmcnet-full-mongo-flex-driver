package jmcnet.mongodb.documents
{
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.bson.BSONDecoder;
	import jmcnet.mongodb.messages.MongoMsgHeader;
	
	import mx.utils.ObjectUtil;

	/**
	 * A response from Mongo database
	 */
	public class MongoDocumentResponse
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoDocumentResponse);
		
		private var _header:MongoMsgHeader;
		private var _responseFlags:int;
		private var _cursorID:Cursor;
		private var _startingFrom:int;
		private var _numberReturned:int;
		[ArrayElementType("newjmcnetds.MongoDocument")]
		private var _documents:Array;
		private var _socket:TimedSocket;
		private var _isOk:Boolean=false;
		private var _errorMsg:String="";
		private var _interpretedResponse:Object=null;
		
		/**
		 * The normal way to construct a MongoDocumentResponse 
		 */
		public function MongoDocumentResponse(length:uint=0, bson:ByteArray=null, socket:TimedSocket=null) {
			super();
			_socket = socket;
			if (bson != null) decodeResponse(length, bson);
		}
		
		/**
		 * The way to construct an error MongoDocumentResponse
		 */
		public static function createErrorResponse(errMsg:String, socket:TimedSocket):MongoDocumentResponse {
			var ret:MongoDocumentResponse = new MongoDocumentResponse();
			ret.errorMsg = errMsg;
			ret.isOk = false;
			return ret;
		}
		
		public function decodeResponse(length:uint, bson:ByteArray):void {
			if (MongoDocument.logDocument) log.debug("Calling decodeResponse length="+length);
			bson.endian = Endian.LITTLE_ENDIAN;
			bson.position = 0;
			_header = new MongoMsgHeader();
			_header.fromBSON(length, bson);
			
			// Flags
			_responseFlags = bson.readUnsignedInt();
			
			// CursorID
			var cidLow:uint = bson.readUnsignedInt();
			var cidHigh:uint = bson.readUnsignedInt();
			_cursorID = new Cursor(cidHigh, cidLow);
			if (MongoDocument.logDocument) log.debug("Cursor received="+_cursorID.toString());
				
			// StartingFrom
			_startingFrom = bson.readUnsignedInt();
			
			// Number docs replied
			_numberReturned = bson.readUnsignedInt();
			
			if (MongoDocument.logDocument) log.debug("MongoDocumentResponse::decodeResponse flags="+_responseFlags+" _cursorID="+_cursorID+" startingFrom="+_startingFrom+" numberReturned="+_numberReturned);
			
			// Docs
			if (_numberReturned > 0) _documents = new Array();
			for (var i:int=0; i<_numberReturned; i++) {
				var document:MongoDocument = decodeDocument(bson);
				_documents.push(document);
			}
			
			if (isFlagQueryFailure()) isOk=false;
			else isOk = true;
			if (MongoDocument.logDocument) log.debug("End of MongoDocumentResponse::decodeResponse result="+ObjectUtil.toString(this));
		}
		
		private function decodeDocument(bson:ByteArray):MongoDocument {
			var doc:MongoDocument =BSONDecoder.decodeBSONToMongoDocument(bson); 
			if (MongoDocument.logDocument) log.debug("MongoDocumentResponse::decodeDocument result="+doc.toString());
			return doc;
		}
		
		public function isFlagCursorNotFound():Boolean { return Boolean(_responseFlags & 0x01); }
		public function isFlagQueryFailure():Boolean { return Boolean(_responseFlags & 0x02); }
		public function isFlagAwaitCapable():Boolean { return Boolean(_responseFlags & 0x08); }
		
		public function toString():String {
			var result:String;
			if (isOk) {
				result="[MongoDocumentResponse - OK - flags="+_responseFlags+" cursorID="+_cursorID+" startingFrom="+_startingFrom+" numberReturned="+_numberReturned+" documents=[";
				for each (var doc:MongoDocument in _documents) {
					result+=doc.toString()+", ";
				}
				result+="]"+" header=["+(header != null ? header.toString():"null")+"]]";
			}
			else result="[MongoDocumentResponse - KO - errorMsg='"+errorMsg+"']"; 
			
			return result;
		}

		public function get header():MongoMsgHeader	{	return _header;	}
		public function getDocument(index:uint):MongoDocument { return _documents != null ? _documents[index]:null;}
		public function get cursorID():Cursor{	return _cursorID;	}
		public function get startingFrom():int {	return _startingFrom;}
		public function get numberReturned():int {	return _numberReturned;	}
		public function get documents():Array {	return _documents;	}

		public function get socket():TimedSocket {	return _socket;	}

		public function get isOk():Boolean { return _isOk;	}
		public function set isOk(value:Boolean):void {	_isOk = value;	}

		public function get errorMsg():String	{	return _errorMsg;	}
		public function set errorMsg(value:String):void	{	_errorMsg = value;}

		public function get interpretedResponse():Object {	return _interpretedResponse; }
		public function set interpretedResponse(value:Object):void { _interpretedResponse = value; }
	}
}