package jmcnet.mongodb.messages.interpreter
{
	import flash.utils.ByteArray;
	
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	
	import mx.collections.ArrayCollection;
	
	/**
	 * This NullResponseInterpreter is the most simple Interpreter. It does only transform the raw response into a simple MongoDocumentResponse
	 */
	public class NullResponseInterpreter implements MongoResponseInterpreterInterface
	{
		public function NullResponseInterpreter()	{}
		
		public function decodeDriverReturn(responseLength:uint, responseByteArray:ByteArray, socket:TimedSocket):MongoDocumentResponse {
			var resp:MongoDocumentResponse = new MongoDocumentResponse(responseLength, responseByteArray, socket);
			resp.interpretedResponse = null;
			return resp;
		}
	}
}