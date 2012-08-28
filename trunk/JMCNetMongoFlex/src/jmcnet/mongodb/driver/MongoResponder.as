package jmcnet.mongodb.driver
{
	import flash.events.Event;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.messages.interpreter.BasicResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.MongoResponseInterpreterInterface;
	
	import mx.rpc.IResponder;
	
	/**
	 * A responder is a class storing callbacks methods (when result is ready or when an error occurs) and a token which is given back to the callback.
	 * This permits to send data across asynchronous call.
	 * @since : version 1.5
	 */
	public class MongoResponder implements IResponder
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoResponder);
		
		public var token:* = null;
		private var _onResult:Function = null;
		private var _onError:Function = null;
		private var _responseInterpreter:MongoResponseInterpreterInterface = null;
		
		/**
		 * Construct a new MongoResponder.
		 * @param onResult:Function : the callback called when a response is ready. The callback signature must be callback(response:MongoDocumentResponse, token:*)
		 * @param onError:Function : the callback called when a error is thrown while communicating with the server. The callback signature must be callback(event:Event, token:*)
		 * @param token:* : any object that will be passed to callback.
		 */
		public function MongoResponder(onResult:Function, onError:Function=null, token:*=null) {
			log.debug("CTOR onResult="+onResult+" onError="+onError+" token="+token);
			this._onResult = onResult;
			this._onError = onError;
			this.token = token;
			_responseInterpreter = new BasicResponseInterpreter();
		}
		
		public function result(response:Object):void {
			log.debug("Calling result response="+response);
			if (_onResult != null) {
				log.debug("There is a result callback. Call it");
				_onResult(response as MongoDocumentResponse, token);
			}
			else log.warn("No result callback. Ignoring response");
		}
		
		public function fault(response:Object):void	{
			log.debug("Calling fault response="+response);
			if (_onError != null) {
				log.debug("There is a fault callback. Call it");
				_onError(response as MongoDocumentResponse, token);
			}
			else if (_onResult != null) {
				log.debug("There is no fault callback but a result callback. Call it");
				_onResult(response as MongoDocumentResponse, token);
			}
		}

		public function get responseInterpreter():MongoResponseInterpreterInterface {	return _responseInterpreter; }
		public function set responseInterpreter(value:MongoResponseInterpreterInterface):void { _responseInterpreter = value;	}

	}
}