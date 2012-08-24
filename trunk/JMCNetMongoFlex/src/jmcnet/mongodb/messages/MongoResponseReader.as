package jmcnet.mongodb.messages 
{
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.ProgressEvent;
	import flash.events.SecurityErrorEvent;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.socketpool.SocketPool;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.driver.MongoResponder;

	/**
	 * Wait and read an answer from Mongo database
	 */
	public class MongoResponseReader
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoResponseReader);
		
		private var _responder:MongoResponder= null;
		private var _socket:TimedSocket=null;
		private var _responseLength:uint=0;
		private var _response:ByteArray=null;
		private var _pool:SocketPool=null;
		
		public function MongoResponseReader(socket:TimedSocket, responder:MongoResponder, socketPool:SocketPool) {
			if (MongoDocument.logDocument) log.info("Starting ...");
			_socket = socket;
			_responder = responder;
			_pool = socketPool;
			_responseLength=0;
			_response = new ByteArray();
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, onDataReceived);
			_socket.addEventListener(IOErrorEvent.IO_ERROR, onError);
			_socket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
		}
		
		private function onDataReceived(event:ProgressEvent):void {
			if (MongoDocument.logDocument) log.evt("onDataReceived Receiving database answer socket #"+_socket.id);
			// initialize responseLenght if not allready done
			if (_responseLength == 0 && _socket.bytesAvailable > 4) {
				_socket.endian = Endian.LITTLE_ENDIAN;
				_responseLength = _socket.readUnsignedInt();
				if (BSONEncoder.logBSON) log.debug("We get the response size : "+_responseLength);
			}

			// Est-ce que le chargement est complet ? +4 car on a deja lu la taille
			if (_responseLength > 0 && _socket.bytesAvailable + 4 == _responseLength) {
				if (MongoDocument.logDocument) log.debug("The response is complete");
				removeListener();
				// Store the answer
				_socket.readBytes(_response);
				if (BSONEncoder.logBSON) log.debug("MongoDB response complete : "+HelperByteArray.byteArrayToString(_response));
				// transform the answer in MongoDocumentResponse
				var reponse:MongoDocumentResponse = new MongoDocumentResponse(_responseLength, _response, _socket);
				log.evt("onDataReceived : Received complete response : "+reponse.toString());
				if (MongoDocument.logDocument) log.debug("Calling callback result method of responder (if there is one)");
				if (_responder != null) _responder.result(reponse);
				// release the socket
				_pool.releaseSocket(_socket as TimedSocket);
			}
			else {
				if (MongoDocument.logDocument) log.debug("The response is not complete. Received="+(_socket.bytesAvailable+4)+" waitingFor="+_responseLength);
				// Wait ...
			}
		}
		
		private function onError(event:Event):void {
			if (MongoDocument.logDocument) log.evt("onError Receiving database answer socket #"+_socket.id);
			removeListener();
			if (MongoDocument.logDocument) log.debug("Calling callback error method of responder (if there is one)");
			if (_responder != null) _responder.fault(event);
			// release the socket
			_pool.releaseSocket(_socket as TimedSocket);
		}
		
		private function removeListener():void {
			//Stop listening the answer
			_socket.removeEventListener(ProgressEvent.SOCKET_DATA, onDataReceived);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, onError);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
		
		}
	}
}