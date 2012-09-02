package jmcnet.mongodb.messages.interpreter
{
	import flash.utils.ByteArray;
	
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.documents.MongoDocumentResponse;

	/**
	 * This class aims to decode a brut response from driver depending on the original command that was send.
	 */
	public interface MongoResponseInterpreterInterface {
		function decodeDriverReturn(responseLength:uint, responseByteArray:ByteArray, socket:TimedSocket):MongoDocumentResponse;
	}
}