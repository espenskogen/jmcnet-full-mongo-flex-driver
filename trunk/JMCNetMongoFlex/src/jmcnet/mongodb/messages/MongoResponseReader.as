package jmcnet.mongodb.messages 
{
	import flash.events.ProgressEvent;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.socketpool.SocketPool;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentResponse;

	/**
	 * Wait and read an answer from Mongo database
	 */
	public class MongoResponseReader
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoResponseReader));
		
		private var _callback:Function = null;
		private var _socket:TimedSocket=null;
		private var _responseLength:uint=0;
		private var _response:ByteArray=null;
		private var _pool:SocketPool=null;
		
		public function MongoResponseReader(socket:TimedSocket, callback:Function, socketPool:SocketPool) {
			if (MongoDocument.logDocument) log.info("MongoResponseReader starting ...");
			_socket = socket;
			_callback = callback;
			_pool = socketPool;
			_responseLength=0;
			_response = new ByteArray();
			_socket.addEventListener(ProgressEvent.SOCKET_DATA, onDataReceived);
		}
		
		private function onDataReceived(event:ProgressEvent):void {
			if (MongoDocument.logDocument) log.evt("MongoResponseReader::onDataReceived Receiving database answer socket #"+_socket.id);
			// initialize responseLenght if not allready done
			if (_responseLength == 0 && _socket.bytesAvailable > 4) {
				_socket.endian = Endian.LITTLE_ENDIAN;
				_responseLength = _socket.readUnsignedInt();
				if (BSONEncoder.logBSON) log.debug("We get the response size : "+_responseLength);
			}

			// Est-ce que le chargement est complet ? +4 car on a deja lu la taille
			if (_responseLength > 0 && _socket.bytesAvailable + 4 == _responseLength) {
				if (MongoDocument.logDocument) log.debug("The response is complete");
				//Stop listening the answer
				_socket.removeEventListener(ProgressEvent.SOCKET_DATA, onDataReceived);
				// Store the answer
				_socket.readBytes(_response);
				if (BSONEncoder.logBSON) log.debug("MongoDB response complete : "+HelperByteArray.byteArrayToString(_response));
				// transform the answer in MongoDocumentResponse
				var reponse:MongoDocumentResponse = new MongoDocumentResponse(_responseLength, _response, _socket);
				if (MongoDocument.logDocument) log.debug("Calling callback method");
				if (MongoDocument.logDocument) log.evt("Received response : "+reponse.toString());
				if (_callback != null) _callback(reponse);
				// release the socket
				_pool.releaseSocket(_socket as TimedSocket);
			}
			else {
				if (MongoDocument.logDocument) log.debug("The response is not complete. Received="+(_socket.bytesAvailable+4)+" waitingFor="+_responseLength);
				// Wait ...
			}
		}
	}
}