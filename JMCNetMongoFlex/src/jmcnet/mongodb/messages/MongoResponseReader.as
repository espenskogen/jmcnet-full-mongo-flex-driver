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
	import jmcnet.mongodb.documents.DBRef;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.driver.EventMongoDB;
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
				// release the socket if it is in use (ie authenticated) and if autoRelease
				if (_socket.inUseTime != 0 && _socket.autoRelease) {
					log.debug("Response is complete, release socket #"+_socket.id+" before interpreting the result.");
					_pool.releaseSocket(_socket as TimedSocket);
				}
				else log.debug("Don't release socket #"+_socket.id+" which is not 'in use' or not autoRelease");

				// transform the answer with Interpreter
				interpretAndCallCallback();
			}
			else {
				if (MongoDocument.logDocument) log.debug("The response is not complete. Received="+(_socket.bytesAvailable+4)+" waitingFor="+_responseLength);
				// Wait ...
			}
		}
		
		private var _nbFetchToReceive:uint=0;
		private var _fetchError:Boolean=false;
		private var _reponse:MongoDocumentResponse = null;
		private var _dbRefInError:DBRef = null;
		
		private function interpretAndCallCallback():void {
			log.evt("Received complete response on socket #"+_socket.id);
			if (_responder != null) {
				_reponse = _responder.responseInterpreter.decodeDriverReturn(_responseLength, _response, _socket);
				log.evt("There is a responder : complete response on socket #"+_socket.id+" is response='"+_reponse.toString()+"'");
				// If there is no error callback but there is a normal callback, call the normal callback
				if (_reponse.isOk) {
					if (MongoDocument.logDocument) log.debug("responder.fetchDbRef="+_responder.fetchDBRef+" maxDBRefDepth="+JMCNetMongoDBDriver.maxDBRefDepth);
					// Check if we need to fetch something
					if (_reponse.documents != null &&
						_reponse.documents.length > 0 &&
						JMCNetMongoDBDriver.maxDBRefDepth > 0 &&
						_responder.fetchDBRef) {
						if (MongoDocument.logDocument) log.debug("Fetching the docs in response");
						_nbFetchToReceive = _reponse.documents.length;
						_fetchError = false;
						for each (var doc:MongoDocument in _reponse.documents) {
							doc.addEventListener(MongoDocument.EVENT_DOCUMENT_FETCH_COMPLETE, onFetchComplete);
							doc.addEventListener(MongoDocument.EVENT_DOCUMENT_FETCH_ERROR, onFetchError);
							doc.fetchDBRef();
						}
					}
					else {
						if (MongoDocument.logDocument) log.debug("Nothing to fetch. Calling callback result method of responder");
						_responder.result(_reponse);
					}
				}
				else {
					if (MongoDocument.logDocument) log.debug("Calling callback error method of responder");
					_responder.fault(_reponse);
				}
			}
			else {
				_reponse = new BasicResponseInterpreter().decodeDriverReturn(_responseLength, _response, _socket);
				log.evt("There is no responder : Received complete response : "+_reponse.toString()+" on socket #"+_socket.id);
			}
		}
		
		private function onFetchComplete(event:EventMongoDB):void {
			if (MongoDocument.logDocument) log.debug("Calling onFetchComplete");
			_nbFetchToReceive--;
			if (_nbFetchToReceive <= 0) {
				if (_fetchError) {
					var msg:String="DBRef Fetching error : almost one of the DBRef could not be deferenced.";
					if (_dbRefInError != null) msg += " Last DBRef in error : "+_dbRefInError.toString();
					if (MongoDocument.logDocument) log.debug("Calling callback error method of responder");
					_responder.fault(MongoDocumentResponse.createErrorResponse(msg, _socket));
				}
				else {
					if (MongoDocument.logDocument) log.debug("All fetch are compelte -> calling callback result method of responder");
					_responder.result(_reponse);
				}
			}
			if (MongoDocument.logDocument) log.debug("EndOf onFetchComplete");
		}
		
		private function onFetchError(event:EventMongoDB):void {
			log.error("Calling onFetchError");
			_fetchError = true;
			if (event.result != null && event.result is DBRef) {
				_dbRefInError = event.result as DBRef;
			}
			onFetchComplete(event);
			log.error("EndOf onFetchError");
		}
		
		private function onError(event:Event):void {
			log.error("onError Receiving database answer socket #"+_socket.id+" event="+event.toString());
			removeListener();
			if (MongoDocument.logDocument) log.debug("Calling callback error method of responder (if there is one)");
			if (_responder != null) _responder.fault(MongoDocumentResponse.createErrorResponse(event.toString(), _socket));
			// release the socket
			if (_socket.autoRelease) _pool.releaseSocket(_socket as TimedSocket);
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