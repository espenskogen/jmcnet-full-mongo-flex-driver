package jmcnet.mongodb.messages.interpreter
{
	import flash.utils.ByteArray;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	
	import mx.collections.ArrayCollection;
	
	
	/**
	 * This ListCollectionsResponseInterpreter interprete the system.namespaces query which permits to list all collections of a databases
	 */
	public class ListCollectionsResponseInterpreter extends BasicResponseInterpreter
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(ListCollectionsResponseInterpreter);
		
		public function ListCollectionsResponseInterpreter()	{ }
		
		/**
		 * Transform the basic response so we can have rep.interpretedResponse containing directly the answer and set isOk to false if we get an err field set by server.
		 * @return response MongoDocumentResponse
		 */
		override public function decodeDriverReturn(responseLength:uint, responseByteArray:ByteArray, socket:TimedSocket):MongoDocumentResponse {
			log.debug("Calling decodeDriverReturn socket #"+socket.id+" responseLength="+responseLength);
			var rep:MongoDocumentResponse = super.decodeDriverReturn(responseLength, responseByteArray, socket);
			// If response is correctly received, check for presence of err which indicate an error in the preceeding command 
			if (rep.isOk) {
				// construct an interpretedResponse as toObject of each document
				rep.interpretedResponse = new ArrayCollection();
				for each (var doc:MongoDocument in rep.documents) {
					var obj:Object = doc.toObject();
					var colName:String = obj.name as String;
//					log.debug("Checking collectionName="+colName);
					// Filters collectionName only
					if (colName.indexOf("$_id_") == -1 && colName.indexOf(".system.") == -1) {
//						log.debug("The collectionName="+colName+" is valid. Add it to the result and revmoe databaseName.");
						(rep.interpretedResponse as ArrayCollection).addItem(colName.substr(colName.lastIndexOf(".")+1));
					}
//					else log.debug("collectionName="+colName+" has been filtred");
				}
			}
			log.debug("EndOf decodeDriverReturn rep="+rep);
			return rep;
		}
	}
}