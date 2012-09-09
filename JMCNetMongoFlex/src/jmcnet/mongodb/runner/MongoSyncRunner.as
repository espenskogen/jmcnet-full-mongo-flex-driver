package jmcnet.mongodb.runner
{
	import flash.errors.IllegalOperationError;
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	
	import jmcnet.libcommun.communs.structures.FifoStack;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.socketpool.EventSocketPool;
	import jmcnet.libcommun.socketpool.SocketPool;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.Cursor;
	import jmcnet.mongodb.documents.JavaScriptCode;
	import jmcnet.mongodb.documents.MongoAggregationPipeline;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentDelete;
	import jmcnet.mongodb.documents.MongoDocumentKillCursors;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.documents.MongoDocumentUpdate;
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.driver.MongoResponder;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;
	import jmcnet.mongodb.messages.MongoMsgAbstract;
	import jmcnet.mongodb.messages.MongoMsgCmd;
	import jmcnet.mongodb.messages.MongoMsgDelete;
	import jmcnet.mongodb.messages.MongoMsgGetMore;
	import jmcnet.mongodb.messages.MongoMsgInsert;
	import jmcnet.mongodb.messages.MongoMsgKillCursors;
	import jmcnet.mongodb.messages.MongoMsgQuery;
	import jmcnet.mongodb.messages.MongoMsgUpdate;
	import jmcnet.mongodb.messages.MongoResponseReader;
	import jmcnet.mongodb.messages.interpreter.AggregationResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.BasicResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.CountResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.DistinctResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.GetLastErrorResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.GroupResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.MapReduceResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.MongoResponseInterpreterInterface;
	
	import mx.utils.ObjectUtil;
	
	/**
	 * A abstract class for running command. A runner permits to send asynchronous commands
	 */
	[Event(name=EVT_RUNNER_COMPLETE, type="jmcnet.mongodb.driver.EventMongoDB")] // dispatched when runner has send all commands and receive all response
	[Event(name=EVT_RUNNER_ERROR, type="jmcnet.mongodb.driver.EventMongoDB")] // dispatched when an error has occured while sending commands
	[Event(name=EVT_LAST_ERROR, type="jmcnet.mongodb.driver.EventMongoDB")]  // dispatched when a response to a getLastError command is received
	[Event(name=EVT_RUN_COMMAND, type="jmcnet.mongodb.driver.EventMongoDB")] // dispatched when a response to a runCommand is received an no responder has been provided
	[Event(name=EVT_RESPONSE_RECEIVED, type="jmcnet.mongodb.driver.EventMongoDB")] // dispatched when a response to a query is received an no responder has been provided
	public class MongoSyncRunner extends AbstractRunner
	{
		public static const EVT_RUNNER_COMPLETE:String="connectOK";
		public static const EVT_RUNNER_ERROR:String="authenticationError";
		public static const EVT_LAST_ERROR:String="lastError";
		public static const EVT_RUN_COMMAND:String="runCommand";
		public static const EVT_RESPONSE_RECEIVED:String="responseReceived";
		
		private var _driver:JMCNetMongoDBDriver=null;
		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoSyncRunner);
		
		private var _started:Boolean=false;
		private var _theSocket:TimedSocket=null;
		private var _continueOnError:Boolean=false;
		// true if a command is on the air
		private var _onAir:Boolean=false;
		
		[ArrayElementType("jmcnet.mongodb.documents.MongoDocumentResponse")]
		private var _tabResponse:Array = new Array();
		
		private var _isOk:Boolean=true;
		
		/**
		 * Build one AsyncRunner.
		 */
		public function MongoSyncRunner(driver:JMCNetMongoDBDriver, continueOnError:Boolean=false) {
			super(driver);
			_driver = driver;
			_continueOnError = continueOnError
			log.info("CTOR databaseName="+_driver.databaseName+" continueOnError="+_continueOnError);
		}
		
		override public function start():void {
			log.info("Starting synchrone Runner...");
			_tabResponse = new Array();
			_isOk = true;
			super.start();
		}
		
		/**
		 * Called when a new message can be send (ie : a socket is free, the runner is started, the preceding message ended)
		 */
		override protected function popAndSendMessage():void {
			log.debug("Calling popAndSendMessage : try to pop and send a message");
			
			if (_onAir) {
				log.info("There is still a message on the air. So wait ...");
				return ;
			}
			// check others conditions
			if (_awaitingMessages.length <= 0) {
				endRunner();
			}
			else {
				super.popAndSendMessage();
			}
			log.debug("EndOf popAndSendMessage.");
		}
		
		private function endRunner():void {
			log.debug("Calling endRunner");
			stop();
			
			if (_theSocket != null) _driver.pool.releaseSocket(_theSocket);
			_theSocket = null;
			if (_isOk) {
				log.evt("MongoSyncRunner : Runner ended with success. Dispatching EVT_RUNNER_COMPLETE");
				dispatchEvent(new EventMongoDB(EVT_RUNNER_COMPLETE, _tabResponse));
			}
			else {
				log.evt("MongoSyncRunner : Runner ended with error. Dispatching EVT_RUNNER_ERROR");
				dispatchEvent(new EventMongoDB(EVT_RUNNER_ERROR, _tabResponse));
			}
			log.debug("EndOf endRunner");
		}
		
		override protected function sendMessageToSocket(msg:MongoMsgAbstract, socket:TimedSocket):void {
			log.debug("Calling sendMessageToSocket msg="+msg.toString()+" socket #"+socket.id);
			_onAir = true;
			super.sendMessageToSocket(msg, socket);
			log.debug("EndOf sendMessageToSocket msg="+msg.toString()+" socket #"+socket.id);
		}
		
		override protected function getConnectedSocket():TimedSocket {
			log.debug("Calling getConnectedSocket");
			if (_theSocket == null) {
				if (!_driver.isConnecte()) {
					log.warn("Not connected to MongoDB");
					throw new ExceptionJMCNetMongoDB("Not connected to MongoDB");
				}
				_theSocket = _driver.pool.getFreeSocket();
				if (_theSocket != null) _theSocket.autoRelease = false; // this socket must not released automatically when a response is received
			}
			
			// When there is no more free socket, just wait...
			log.debug("EndOf getConnectedSocket theSocket="+(_theSocket!= null ? " socket #"+_theSocket.id:"null"));
			return _theSocket;
		}
		
		override protected function releaseSocket(socket:TimedSocket):void {
			log.debug("Calling releaseSocket socket #"+socket.id);
			_onAir = false;
			popAndSendMessage();
		}
		
		override protected function prepareMsgForSending(msg:MongoMsgAbstract, responder:MongoResponder):void {
			log.debug("Calling prepareMsgForSending");
			
//			msg.responder = responder;
			msg.responder = new MongoResponder(onSyncRunnerResult, onSyncRunnerError, responder, (responder != null ? responder.fetchDBRef:true));
			if (responder != null && responder.responseInterpreter != null) msg.responder.responseInterpreter = responder.responseInterpreter;
			
			if (!_started || _onAir || _awaitingMessages.length > 0) {
				_awaitingMessages.push(msg);
				log.debug("prepareMsgForSending : Runner is not started or there is a command on the air, or still waiting commands, so wait...");
			}
			else {
				var socket:TimedSocket=getConnectedSocket();
				if (socket != null) {
					log.debug("There is an available socket and runner is started -> sends directly in socket #"+socket.id);
					sendMessageToSocket(msg, socket);
				}
				else {
					log.info("There is no more available socket. We have to wait ...");
					_awaitingMessages.push(msg);
				}
			}
			
			log.debug("EndOf prepareMsgForSending awaitingMessages.length="+_awaitingMessages.length);
		}
		
		private function onSyncRunnerResult(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onSyncRunnerResult response="+response.toString());
			_onAir = false;
			// The token is the original responder
			var responder:MongoResponder = token as MongoResponder;
			if (responder != null) {
				log.debug("There is a responder -> call result");
				responder.result(response);
			}
			_tabResponse.push(response);
			popAndSendMessage();
		}
		
		private function onSyncRunnerError(response:MongoDocumentResponse, token:*):void {
			log.error("Calling onSyncRunnerError response="+response.toString());
			_onAir = false;
			_isOk = false;
			// The token is the original responder
			var responder:MongoResponder = token as MongoResponder;
			if (responder != null) {
				log.debug("There is a responder -> call fault");
				responder.fault(response);
			}
			_tabResponse.push(response);
			if (!_continueOnError) {
				log.error("There is an error : "+response.toString()+" and we should not continue.");
				endRunner();
			}
			else {
				log.debug("User decide to continue..."); 
				popAndSendMessage();
			}
		}
		
		override public function toString():String {
			return "[SyncRunner databaseName="+_driver.databaseName+"]";
		}		

		public function get isOk():Boolean	{ return _isOk; }
	}
}