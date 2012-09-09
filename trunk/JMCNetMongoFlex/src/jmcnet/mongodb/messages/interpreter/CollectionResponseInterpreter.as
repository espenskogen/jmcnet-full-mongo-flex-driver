package jmcnet.mongodb.messages.interpreter
{
	import flash.utils.ByteArray;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	
	
	/**
	 * This BasicResponseInterpreter is the default one. It does only transform the raw response into a simple MongoDocumentResponse
	 */
	public class CollectionResponseInterpreter extends BasicResponseInterpreter
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(CollectionResponseInterpreter);
		
		public function CollectionResponseInterpreter()	{ }
		
		/**
		 * Transform the basic response so we can have rep.interpretedResponse containing directly the answer and set isOk to false if we get an err field set by server.
		 * @return response MongoDocumentResponse
		 */
		override public function decodeDriverReturn(responseLength:uint, responseByteArray:ByteArray, socket:TimedSocket):MongoDocumentResponse {
			log.debug("Calling decodeDriverReturn socket #"+socket.id+" responseLength="+responseLength);
			var rep:MongoDocumentResponse = super.decodeDriverReturn(responseLength, responseByteArray, socket);
			// If response is correctly received, check for presence of err which indicate an error in the preceeding command 
			if (rep.isOk) {
				if (rep.interpretedResponse.length == 1) {
					rep.interpretedResponse = rep.interpretedResponse[0];
					if ((rep.interpretedResponse.hasOwnProperty("ok") && rep.interpretedResponse.ok == 0) || (rep.interpretedResponse.hasOwnProperty("errmsg") && rep.interpretedResponse.errmsg != null)) {
						rep.isOk = false;
						rep.errorMsg = rep.interpretedResponse.errmsg;
						log.warn("There is an err field -> mark the response as in error. ErrorMsg="+rep.errorMsg);
					}
				}
				else {
					rep.isOk = false;
					rep.errorMsg = "Error : CollectionResponseInterpreter don't get one document in response but gets "+rep.interpretedResponse.length+" documents.";
				}
			}
			log.debug("EndOf decodeDriverReturn rep="+rep.toString());
			return rep;
		}
	}
}