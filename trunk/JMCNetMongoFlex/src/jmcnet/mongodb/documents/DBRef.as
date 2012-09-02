package jmcnet.mongodb.documents
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.driver.MongoResponder;
	
	/**
	 * A class representing a database reference attribute.
	 * @event EVENT_FETCH_COMPLETE dispatched when the fetch operation is complete for this DBRef
	 */
	[Event(name=EVENT_FETCH_COMPLETE, type="jmcnet.mongodb.driver.EventMongoDB")]
	[Event(name=EVENT_FETCH_ERROR, type="jmcnet.mongodb.driver.EventMongoDB")]
	public class DBRef extends EventDispatcher
	{
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(DBRef);
		
		public static const EVENT_DBREF_FETCH_COMPLETE:String="FetchComplete";
		public static const EVENT_DBREF_FETCH_ERROR:String="FetchError";
		
		private var _collectionName:String=null;
		private var _id:ObjectID=null;
		private var _databaseName:String=null;
		private var _value:Object=null;
		private var _documentValue:MongoDocument=null;
		
		// The depth in a object, this DBRef has been found 
		private var _depth:uint=0;
		
		/**
		 * Construct a new DBRef. if databaseName is null this mean, in the current database (use it only if you are mono databaseName).
		 * @param collectionName (String) The name of the collection to search in. Equivalent to $ref parameter in DBRef
		 * @param id (OBjectID or String) The id of object to search. Equivalent to $id parameter in DBRef
		 * @param databaseName (String) The name of the database to search in. Equivalent to $db parameter in DBRef. If null, suppose to search in the only open database.
		 */
		public function DBRef(collectionName:String, id:Object, databaseName:String=null) {
			log.debug("CTOR collectionName="+collectionName+" id="+id+" databaseName="+databaseName);
			_collectionName = collectionName;
			if (id is ObjectID) _id = id as ObjectID;
			else _id = ObjectID.createFromString(id.toString());
			_databaseName = databaseName;
		}
		
		/**
		 * Retrieve the value of the DBRef and store it.
		 * @throws ExceptionJMCNetMongoDB if no driver if found for databaseName of this DBRef
		 */
		public function fetch():void {
			log.info("Calling fetch dbref="+toString());
			 var driver:JMCNetMongoDBDriver = JMCNetMongoDBDriver.findDriver(_databaseName);
			 // call findOne for $_id of collection supplied
			 var query:MongoDocumentQuery = new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", _id));
			 driver.queryDoc(_collectionName, query, new MongoResponder(onFetchComplete, onFetchError, null, false), null, 0, 1);
		}
		
		private function onFetchComplete(result:MongoDocumentResponse, token:*=null):void {
			log.evt("Calling onFetchComplete dbref="+toString()+" result="+(result != null ? result.toString():"null")+" token="+token);
			
			if (result.interpretedResponse == null || result.interpretedResponse.length != 1) {
				log.error("Error : fetching DBRef '"+this.toString()+" in error (Referenced object not found ?)");
				onFetchError(result);
				log.info("EndOf onFetchComplete dbref="+toString());
				return ;
			}
			// Store the result and dispatch EVENT_FETCH_COMPLETE event
			_value = result.interpretedResponse[0];
			_documentValue = result.documents[0];
			
			log.evt("Dispatching EVENT_FETCH_COMPLETE DBRef="+toString());
			this.dispatchEvent(new EventMongoDB(EVENT_DBREF_FETCH_COMPLETE));
				
			log.info("EndOf onFetchComplete dbref="+toString());
		}
		
		private function onFetchError(result:MongoDocumentResponse, token:*=null):void {
			log.evt("Calling onFetchError dbref="+toString()+" result="+(result != null ? result.toString():"null")+" token="+token);
			
			// Dispatch EVENT_FETCH_ERROR event
			log.evt("Dispatching EVENT_FETCH_ERROR DBRef="+toString());
			this.dispatchEvent(new EventMongoDB(EVENT_DBREF_FETCH_ERROR, this));
			
			log.info("EndOf onFetchError dbref="+toString());
		}
		
		public function toMongoDocument():MongoDocument {
			var ret:MongoDocument = new MongoDocument("$ref", _collectionName).addKeyValuePair("$id", _id);
			if (_databaseName != null) ret.addKeyValuePair("$db", _databaseName);
			return ret;
		}
		
		override public function toString():String {
			var ret:String="DBRef($ref : "+_collectionName+", $id : "+_id;
			if (_databaseName != null) ret += ", $db : "+_databaseName;
			if (documentValue != null) ret += ", value : "+documentValue.toString();
			ret += ")";
			return ret;
		}

		public function get collectionName():String	{ return _collectionName; }
		public function set collectionName(value:String):void {	_collectionName = value; }

		public function get id():ObjectID {	return _id;	}
		public function set id(value:ObjectID):void { _id = value; }

		public function get databaseName():String {	return _databaseName; }
		public function set databaseName(value:String):void	{ _databaseName = value; }

		public function get value():Object { return _value;	}
		public function get documentValue():MongoDocument { return _documentValue;	}

		/**
		 * The depth in a object, this DBRef has been found
		 */
		public function get depth():uint {	return _depth;	}
		public function set depth(value:uint):void { _depth = value; }

	}
}