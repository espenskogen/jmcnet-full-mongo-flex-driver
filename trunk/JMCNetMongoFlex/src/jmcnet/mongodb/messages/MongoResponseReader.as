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
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.driver.MongoResponder;
	import jmcnet.mongodb.messages.interpreter.BasicResponseInterpreter;

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
			if (MongoDocument.logDocument) log.info("Starting on socket #"+socket.id+" ...");
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
			if (MongoDocument.logDocument) log.debug("onDataReceived Receiving database answer socket #"+_socket.id);
			// initialize responseLenght if not allready done
			if (_responseLength == 0 && _socket.bytesAvailable > 4) {
				_socket.endian = Endian.LITTLE_ENDIAN;
				_responseLength = _socket.readUnsignedInt();
				if (BSONEncoder.logBSON) log.debug("We get the response size : "+_responseLength);
			}

			// Est-ce que le chargement est complet ? +4 car on a deja lu la taille
			if (_responseLength > 0 && _socket.bytesAvailable + 4 == _responseLength) {
				if (MongoDocument.logDocument) log.debug("The response is complete is socket #"+_socket.id);
				removeListener();
				// Store the answer
				_socket.readBytes(_response);
				if (BSONEncoder.logBSON) log.debug("MongoDB response complete : "+HelperByteArray.byteArrayToString(_response));
				// release the socket if it is in use (ie authenticated)
				if (_socket.inUseTime != 0) {
					log.debug("Response is complete, release socket #"+_socket.id+" before interpreting the result.");
					_pool.releaseSocket(_socket as TimedSocket);
				}
				else log.debug("Don't release socket #"+_socket.id+" which is not 'in use'");

				// transform the answer with Interpreter
				interpretAndCallCallback();
			}
			else {
				if (MongoDocument.logDocument) log.debug("The response is not complete. Received="+(_socket.bytesAvailable+4)+" waitingFor="+_responseLength);
				// Wait ...
			}
		}
		
		private function interpretAndCallCallback():void {
			var reponse:MongoDocumentResponse = null;
			if (_responder != null) {
				reponse = _responder.responseInterpreter.decodeDriverReturn(_responseLength, _response, _socket);
				log.evt("Received complete response on socket #"+_socket.id+" :  response='"+reponse.toString()+"'");
				// If there is no error callback but there is a normal callback, call the normal callback
				if (reponse.isOk) {
					if (MongoDocument.logDocument) log.debug("Calling callback result method of responder");
					_responder.result(reponse);
				}
				else {
					if (MongoDocument.logDocument) log.debug("Calling callback error method of responder");
					_responder.fault(reponse);
				}
			}
			else {
				reponse = new BasicResponseInterpreter().decodeDriverReturn(_responseLength, _response, _socket);
				log.evt("onDataReceived with no responder : Received complete response : "+reponse.toString()+" on socket #"+_socket.id);
			}
		}
		
		private function onError(event:Event):void {
			log.error("onError Receiving database answer socket #"+_socket.id+" event="+event.toString());
			removeListener();
			if (MongoDocument.logDocument) log.debug("Calling callback error method of responder (if there is one)");
			if (_responder != null) _responder.fault(MongoDocumentResponse.createErrorResponse(event.toString(), _socket));
			// release the socket
			_pool.releaseSocket(_socket as TimedSocket);
			log.error("onError socket #"+_socket.id+" has been released due of error");
		}
		
		private function removeListener():void {
			//Stop listening the answer
			_socket.removeEventListener(ProgressEvent.SOCKET_DATA, onDataReceived);
			_socket.removeEventListener(IOErrorEvent.IO_ERROR, onError);
			_socket.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onError);
		
		}
	}
}