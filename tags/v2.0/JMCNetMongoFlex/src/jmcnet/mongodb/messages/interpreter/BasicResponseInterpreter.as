package jmcnet.mongodb.messages.interpreter
{
	import flash.utils.ByteArray;
	
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	
	import mx.collections.ArrayCollection;
	
	/**
	 * This BasicResponseInterpreter is the default one. It does only transform the raw response into a simple MongoDocumentResponse
	 */
	public class BasicResponseInterpreter implements MongoResponseInterpreterInterface
	{
		public function BasicResponseInterpreter()	{}
		
		public function decodeDriverReturn(responseLength:uint, responseByteArray:ByteArray, socket:TimedSocket):MongoDocumentResponse {
			var resp:MongoDocumentResponse = new MongoDocumentResponse(responseLength, responseByteArray, socket);
			if (resp.isOk) {
				// construct an interpretedResponse as toObject of each document
				resp.interpretedResponse = new ArrayCollection();
				for each (var doc:MongoDocument in resp.documents) {
					(resp.interpretedResponse as ArrayCollection).addItem(doc.toObject());
				}
			}
			return resp;
		}
	}
}