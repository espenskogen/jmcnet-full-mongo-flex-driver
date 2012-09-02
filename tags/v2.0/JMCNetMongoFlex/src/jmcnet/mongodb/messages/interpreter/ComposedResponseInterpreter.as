package jmcnet.mongodb.messages.interpreter
{
	import flash.utils.ByteArray;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	
	import mx.utils.ObjectUtil;
	
	/**
	 * This BasicResponseInterpreter is the default one. It does only transform the raw response into a simple MongoDocumentResponse
	 */
	public class ComposedResponseInterpreter implements MongoResponseInterpreterInterface
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(ComposedResponseInterpreter);
		
		// The name of the field containing the response
		private var _resultFieldName:String="noname";
		
		public function ComposedResponseInterpreter(resultFieldName:String)	{ _resultFieldName = resultFieldName; }
		
		public function decodeDriverReturn(responseLength:uint, responseByteArray:ByteArray, socket:TimedSocket):MongoDocumentResponse {
			var resp:MongoDocumentResponse = new MongoDocumentResponse(responseLength, responseByteArray, socket);
			if (resp.isOk) {
				// Normally there is only one document...
				if (resp.documents.length == 1) {
					var aggregResult:Object = (resp.documents[0] as MongoDocument).toObject();
					log.debug("Received aggregResult : "+ObjectUtil.toString(aggregResult));
					
					if (!aggregResult.ok) {
						resp.isOk = false;
						resp.errorMsg = "("+aggregResult.code+") : "+aggregResult.errmsg;
						log.error("The result of aggregation command is KO errorMsg="+resp.errorMsg);
					}
					else {
						resp.interpretedResponse = aggregResult[_resultFieldName];
					}
				}
				else {
					resp.isOk = false;
					resp.errorMsg = "Error : An aggregation response must contains one and only one result document.";
					log.error(resp.errorMsg);
				}
			}
			return resp;
		}
	}
}