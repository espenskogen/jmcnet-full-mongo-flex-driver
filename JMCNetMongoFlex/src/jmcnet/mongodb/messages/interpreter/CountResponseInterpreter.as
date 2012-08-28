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
	public class CountResponseInterpreter extends ComposedResponseInterpreter
	{
		public function CountResponseInterpreter()	{ super("n"); }
	}
}