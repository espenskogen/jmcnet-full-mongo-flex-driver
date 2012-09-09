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
	import jmcnet.mongodb.messages.interpreter.CollectionResponseInterpreter;
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
	public class AbstractRunner extends EventDispatcher
	{
		public static const EVT_RUNNER_COMPLETE:String="connectOK";
		public static const EVT_RUNNER_ERROR:String="authenticationError";
		public static const EVT_LAST_ERROR:String="lastError";
		public static const EVT_RUN_COMMAND:String="runCommand";
		public static const EVT_RESPONSE_RECEIVED:String="responseReceived";
		
		private var _driver:JMCNetMongoDBDriver=null;
		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(AbstractRunner);
		
		// The waiting for pool commands
		[ArrayElementType("jmcnet.mongodb.messages.MongoMsgAbstract")]
		protected var _awaitingMessages:FifoStack = new FifoStack();
		
		private var _started:Boolean=false;
		
		/**
		 * Build one AsyncRunner.
		 */
		public function AbstractRunner(driver:JMCNetMongoDBDriver) {
			if(flash.utils.getQualifiedClassName(super) == "jmcnet.mongodb.runner::AbstractAsyncRunner")
				throw new IllegalOperationError("AbstractAsyncRunner class is abstract and it cannot be instantiated.");
			_driver = driver;
			log.info("CTOR databaseName="+_driver.databaseName);
		}
		
		/**
		 * Starts the runner to send command to database.
		 */
		public function start():void {
			log.debug("Starting Runner");
			_started = true;
			// We listen for available sockets in the pool
			_driver.pool.addEventListener(SocketPool.EVENT_FREE_SOCKET,onFreeSocket);
			// do as is a free socket was freed to send first waiting message
			popAndSendMessage();
		}
		
		/**
		 * Stops the runner to send command to database. Commands are storred in a fifo stack to be played later.
		 */
		public function stop():void {
			_started = false;
			// Stop listen for available sockets in the pool
			_driver.pool.removeEventListener(SocketPool.EVENT_FREE_SOCKET,onFreeSocket);
		}
		
		public function get started():Boolean { return _started;}
		
		/**
		 * Insert one or more documents in a collection
		 * @param collectionName (String) : the name of the collection to insert into,
		 * @param documents (Array of Object or MongoDocument) : the objects to insert,
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 * @param continueOnError (Boolean) : true if must continue when there is an error. Default value is false.
		 */
		public function insertDoc(collectionName:String, documents:Array, safeResponder:MongoResponder=null, continueOnError:Boolean=true):void {
			log.info("Calling insertDoc collectionName="+collectionName+" safeResponder="+safeResponder+" continueOnError="+continueOnError+" documents="+ObjectUtil.toString(documents)); 
			
			var msg:MongoMsgInsert = new MongoMsgInsert(_driver.databaseName, collectionName, continueOnError);
			for each (var doc:Object in documents) {
				msg.addDocument(doc);
			}
			
			prepareMsgForSending(msg, safeResponder);
		}
		
		/**
		 * Query documents (ie. find, findOne, find.skip, find.limit).
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param query (MongoDocumentQuery) : the query document,
		 * @param responder (MongoResponder) : the callback called when documents are ready to read. Default value is null,
		 * @param returnFields (MongoDocument) : list of field included in the response. Default is null (all fields are returned),
		 * @param numberToSkip (uint) : number of docs to skip. Usefull for pagination. Default is 0,
		 * @param numberToReturn (uint) : number of docs to return. Usefull for pagination. Default is 0 (returns default documents number),
		 * @param taillableCursor (Boolean) : if true opens and returns a taillable cursor,
		 * @param slaveOk (Boolean) : if true query can be send to an arbitrary slave,
		 * @param noCursorTimeout (Boolean) : if true the cursor is never kill even if not use for a while,
		 * @param awaitData (Boolean) : Use with TailableCursor. If we are at the end of the data, block for a while rather than returning no data. After a timeout period, we do return as normal.
		 * @param exhaust (Boolean) : Stream the data down full blast in multiple "more" packages, on the assumption that the client will fully read all data queried. Faster when you are pulling a lot of data and know you want to pull it all down. Note: the client is not allowed to not read all the data unless it closes the connection.
		 * @param partial (Boolean) : Get partial results from a mongos if some shards are down (instead of throwing an error) 
		 * */
		public function queryDoc(collectionName:String, query:MongoDocumentQuery, responder:MongoResponder=null, returnFields:MongoDocument=null,
								 numberToSkip:uint=0, numberToReturn:int=0, tailableCursor:Boolean=false, slaveOk:Boolean=false, noCursorTimeout:Boolean=false,
								 awaitData:Boolean=false, exhaust:Boolean=false, partial:Boolean=false ):void {
			log.info("Calling query collectionName="+collectionName+" query="+query.toString()+" responder="+responder+" returnFields="+ObjectUtil.toString(returnFields)+" numberToSkip="+numberToSkip+" numberToReturn="+numberToReturn);
			
			var msg:MongoMsgQuery = prepareQuery(collectionName, query, returnFields, numberToSkip, numberToReturn, tailableCursor, awaitData, exhaust, partial);
			
			if (responder == null) responder = new MongoResponder(onResponseQueryReady);
			prepareMsgForSending(msg, responder);
		}
		
		/**
		 * Retrieve more documents on an open cursor. To open Cursor, you can call queryDoc and gets the cursorID in the response.
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param cursorID (Cursor) : the cursor to fetch datas from. Cames from a preceding call to queryDoc,
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
		 * @param numberToReturn (uint) : number of docs to return. Usefull for pagination. Default is 0 (returns default documents number)
		 */
		public function getMoreDoc(collectionName:String, cursorID:Cursor, responder:MongoResponder=null, numberToReturn:int=0):void {
			log.info("Calling getMore collectionName="+collectionName+" cursorID="+cursorID+" numberToReturn="+numberToReturn);
			
			var msg:MongoMsgGetMore = new MongoMsgGetMore(_driver.databaseName, collectionName, cursorID, numberToReturn);
			
			if (responder == null) responder = new MongoResponder(onResponseQueryReady);
			prepareMsgForSending(msg, responder);
		}
		
		/**
		 * Default callback when not specified by user
		 */
		private function onResponseQueryReady (response:MongoDocumentResponse,token:*):void {
			log.debug("Calling onResponseReady response="+response.toString()+" token="+token);
			// Dispatch the answer
			this.dispatchEvent(new EventMongoDB(EVT_RESPONSE_RECEIVED, response));
		}
		
		/**
		 * Send a command to the database. A command has no result in return.
		 * @param command (MongoDocument) : the command,
		 * @param responder (Responder) : the responder called with command's results.
		 * @param interpreter (MongoResponseInterpreter) : a interpretor class which exploit the result a transform this in MongoDocumentResponse.interpretedResponse object.
		 */
		public function runCommand(command:MongoDocument, responder:MongoResponder=null, interpreter:MongoResponseInterpreterInterface=null ):void {
			log.info("Calling runCommand command="+command.toString()+" responder="+responder);
			var msg:MongoMsgCmd = new MongoMsgCmd(_driver.databaseName);
			msg.cmd = command;
			
			// Normally there is no answer... but in safe mode we could 
			if (responder == null) responder = new MongoResponder(onResponseRunCommandReady);
			if (interpreter == null) responder.responseInterpreter = new BasicResponseInterpreter();
			else responder.responseInterpreter = interpreter;
			
			prepareMsgForSending(msg, responder);
			log.info("EndOf runCommand");
		}
		
		/**
		 * Send a query command to the database. Query commands are commands which has a result.
		 * @param command (MongoDocument) : the command,
		 * @param responder (Responder) : the responder called with command's results.
		 */
		public function runQueryCommand(command:MongoDocument, responder:MongoResponder=null, interpreter:MongoResponseInterpreterInterface=null ):void {
			log.info("Calling runQueryCommand command="+command.toString()+" responder="+responder);
			var msg:MongoMsgQuery = prepareQuery("$cmd", new MongoDocumentQuery(command), null, 0, -1);
			if (responder == null) responder = new MongoResponder(onResponseRunCommandReady);
			if (interpreter == null) responder.responseInterpreter = new BasicResponseInterpreter();
			else responder.responseInterpreter = interpreter;
			
			prepareMsgForSending(msg, responder);
			log.info("EndOf runQueryCommand");
		}
		
		private function onResponseRunCommandReady (response:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseRunCommandReady response="+response.toString()+" token="+token);
			// Dispatch the answer
			log.evt("Dispatching Run command event");
			this.dispatchEvent(new EventMongoDB(EVT_RUN_COMMAND, response));
		}
		
		/**
		 * Call the getLastError method and return the result in the responder
		 */
		public function getLastError(responder:MongoResponder=null):void {
			log.info("Calling getLastError responder="+responder);
			runQueryCommand(_driver.lastErrorDoc, responder == null ? new MongoResponder(onResponseLastError):responder, new GetLastErrorResponseInterpreter());
		}
		
		private function onResponseLastError(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseLastError response="+response.toString()+" token="+token);
			this.dispatchEvent(new EventMongoDB(EVT_LAST_ERROR, response));
		}
		
		/**
		 * Update one or more documents of a collection.
		 * @param collectionName (String) : the name of the collection,
		 * @param update (MongoDocumentUpdate) : the update query and modifications,
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 * @param upsert (Boolean) : if true can perform an insert if doc don't exists. Default value is false,
		 * @param multiupdate (Boolean) : if true can perform update one more than one document. Default value is false,
		 */
		public function updateDoc(collectionName:String, update:MongoDocumentUpdate, safeResponder:MongoResponder= null, upsert:Boolean=false, multiUpdate:Boolean=false):void {
			log.info("Calling update collectionName="+collectionName+" safeResponder="+safeResponder+" update="+update+" upsert="+upsert+" multiUpdate="+multiUpdate);
			
			var msg:MongoMsgUpdate = new MongoMsgUpdate(_driver.databaseName, collectionName, update, upsert, multiUpdate);
			
			// Write into socket
			prepareMsgForSending(msg, safeResponder);
		}
		
		/**
		 * Delete one or more documents of a collection.
		 * @param collectionName (String) : the name of the collection,
		 * @param delete (MongoDocumentDelete) : the delete query,
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 * @param singleRemove (Boolean) : if true perform a single remove. Default value is false.
		 */
		public function deleteDoc(collectionName:String, doc:MongoDocumentDelete, safeResponder:MongoResponder= null, singleRemove:Boolean=false):void {
			log.info("Calling deleteDoc collectionName="+collectionName+" safeResponder="+safeResponder+" deleteDoc="+doc+" singleRemove="+singleRemove);
			
			var msg:MongoMsgDelete = new MongoMsgDelete(_driver.databaseName, collectionName, doc, singleRemove);
			
			// Write into socket
			prepareMsgForSending(msg, safeResponder);
		}
		
		/**
		 * Kills an existing cursor on a collection.
		 * @param doc (MongoDocumentKillCursors) : the document containing the cursor(s) to kill,
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 */
		public function killCursors(doc:MongoDocumentKillCursors, safeResponder:MongoResponder=null):void {
			log.info("Calling killCursor safeResponder="+safeResponder+" doc="+ObjectUtil.toString(doc));
			
			var msg:MongoMsgKillCursors = new MongoMsgKillCursors(doc);
			
			// Write into socket
			prepareMsgForSending(msg, safeResponder);
		}
		
		/**
		 * Create a collection.
		 * @param collectionName (String) : the name of the collection to create
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 */
		public function createCollection(collectionName:String,  safeResponder:MongoResponder=null):void {
			log.info("Calling createCollection collectionName="+collectionName+" safeResponder="+safeResponder);
			runQueryCommand(new MongoDocument("create",collectionName), safeResponder, new CollectionResponseInterpreter());
		}
		
		/**
		 * Drop a collection.
		 * @param collectionName (String) : the name of the collection to drop
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 */
		public function dropCollection(collectionName:String,  safeResponder:MongoResponder=null):void {
			log.info("Calling dropCollection collectionName="+collectionName+" safeResponder="+safeResponder);
			
			runQueryCommand(new MongoDocument("drop",collectionName), safeResponder, new CollectionResponseInterpreter());
		}
		
		/**
		 * Rename a collection.
		 * @param collectionName (String) : the name of the collection to rename
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 */
		public function renameCollection(collectionName:String, newCollectionName:String, safeResponder:MongoResponder=null):void {
			log.info("Calling renameCollection collectionName="+collectionName+" newCollectionName="+newCollectionName+" safeResponder="+safeResponder);
			runQueryCommand(new MongoDocument("renameCollection",_driver.databaseName+"."+collectionName).addKeyValuePair("to",_driver.databaseName+"."+newCollectionName), safeResponder, new CollectionResponseInterpreter());
		}
		
		/**
		 * Count how many documents are compliant to a query.
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param query (MongoDocument) : the conditions document,
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
		 * @param skip (uint) : number of docs to skip. Usefull for pagination. Default is 0,
		 * @param limit (uint) : number of docs max to return. Usefull for pagination. Default is 0 (returns default documents number),
		 * @param snapshot (Boolean) : if true makes a snapshot before counting.
		 */
		public function count(collectionName:String, query:MongoDocument=null, responder:MongoResponder=null, skip:uint=0, limit:uint=0, snapshot:Boolean=false):void {
			log.info("Calling count collectionName="+collectionName+" responder="+responder+" skip="+skip+" limit="+limit+" snapshot="+snapshot);
			var cmd:MongoDocument = new MongoDocument("count",collectionName);
			if (query != null) cmd.addKeyValuePair("query", query);
			if (skip != 0) cmd.addKeyValuePair("skip", skip);
			if (limit != 0) cmd.addKeyValuePair("limit", limit);
			if (snapshot != false) cmd.addKeyValuePair("snapshot", snapshot);
			
			runQueryCommand(cmd, responder, new CountResponseInterpreter());
		}
		
		/**
		 * Retrieve distinct documents compliant to a query.
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param key (String) : the key used to distinct documents,
		 * @param query (MongoDocument) : the conditions document,
		 * @param responder (MongoResponder) : the callback called when documents are ready to read. Default value is null,
		 */
		public function distinct(collectionName:String, key:String, query:MongoDocument=null, responder:MongoResponder=null):void {
			log.info("Calling distinct collectionName="+collectionName+" key="+key+" responder="+responder);
			var cmd:MongoDocument = new MongoDocument("distinct",collectionName);
			if (key != null) cmd.addKeyValuePair("key", key);
			if (query != null) cmd.addKeyValuePair("query", query);
			
			runQueryCommand(cmd, responder, new DistinctResponseInterpreter());
		}
		
		/**
		 * Retrieve documents and group them among a key.
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param key (String) : the key used to group documents (see keyf param above),
		 * @param reduce (JavaScriptCode) : a reduce JS function executed on the group. JS signature must be "function(obj, result):void",
		 * @param initial (MongoDocument) : a list of key/value pairs used to initialize variables,
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
		 * @param keyf (JavaScriptCode) : a JS function used to calculate a key for grouping. keyf signature must be : "function(doc):{keyName: valueOfKeyForDoc}". Cf. One of key/keyf param must be provided. Default value is null,
		 * @param cond (MongoDocument) : a document used to filter documents that will be grouped. Default value is null (all documents are considered),
		 * @param finalize (JavaScriptCode) : a JS function used to finalize the result. JS signature must be "function(result):void". Default value is null (no finalization).
		 */
		public function group(collectionName:String, key:MongoDocument, reduce:JavaScriptCode, initial:MongoDocument, responder:MongoResponder=null, keyf:JavaScriptCode=null, cond:MongoDocument=null, finalize:JavaScriptCode=null):void {
			log.info("Calling group collectionName="+collectionName+" key="+key+" reduce="+reduce+" initial="+initial+" responder="+responder+" keyf="+keyf+" cond="+cond+" finalize="+finalize);
			var grpCmd:MongoDocument= new MongoDocument();
			if (collectionName != null) grpCmd.addKeyValuePair("ns", collectionName);
			if (key != null) grpCmd.addKeyValuePair("key", key);
			if (reduce != null) grpCmd.addKeyValuePair("$reduce", reduce);
			if (initial != null) grpCmd.addKeyValuePair("initial", initial);
			if (keyf != null) grpCmd.addKeyValuePair("$keyf", keyf);
			if (cond != null) grpCmd.addKeyValuePair("cond", cond);
			if (finalize != null) grpCmd.addKeyValuePair("finalize", finalize);
			var cmd:MongoDocument = new MongoDocument("group", grpCmd); 
			
			runQueryCommand(cmd, responder, new GroupResponseInterpreter());
		}
		
		/**
		 * Map and reduce documents. Example of scope ('init=0' and a JS function called 'myScopedFct=new Date()') : new MongoDocument("init", 0).addKeyValuePair("myScopedFct", new JavaScriptCodeScoped("new Date()"))
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param map (JavaScriptCode) : the map JS function. JS signature must be "function():void". You must call 'emit(key, value)' in the JS function,
		 * @param reduce (JavaScriptCode) : the reduce JS function executed on the documents grouped by key. JS signature must be "function (key, emits):{key, value}",
		 * @param out (MongoDocument) : specificy how to output the result. Values can be. See http://www.mongodb.org/display/DOCS/MapReduce#MapReduce-Outputoptions,
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
		 * @param query (MongoDocument) : a document used to filter documents that will be map/reduced. Default value is null (all documents are considered),
		 * @param sort (MongoDocument) : a document specifiying the sort order. Default value is null (no sort),
		 * @param limit (uint) : limit the number of documents considered. Usefull only with sort. Default is 0 (no limit),
		 * @param finalize (JavaScriptCode) : a JS function used to finalize the result. JS signature must be "function(key, result):result". Default value is null (no finalization).
		 * @param scope (MongoDocument) : a document specifiying the scoped variables. Scoped variables are global variables usable in all JS. If the value of a variable is a JS code, you must use JavaScriptCodeScoped to specify the code. Default value is null (no scope variables),
		 * @param jsMode (Boolean) : if true, all JS is executed in one JS instance. Default value is false,
		 * @param verbose (Boolean) : if true output all 'print' JS command to the server logs. Default is false.
		 */
		public function mapReduce(collectionName:String, map:JavaScriptCode, reduce:JavaScriptCode, out:MongoDocument, responder:MongoResponder=null,
								  query:MongoDocument=null, sort:MongoDocument=null, limit:uint=0, finalize:JavaScriptCode=null,
								  scope:MongoDocument=null, jsMode:Boolean=false, verbose:Boolean=false):void {
			log.info("Calling mapReduce collectionName="+collectionName+" map="+map+" reduce="+reduce+" out="+out+" responder="+responder+
				" query="+query+" sort="+sort+" limit="+limit+" finalize="+finalize+" scope="+scope+" jsMode="+jsMode+" verbose="+verbose);
			var mapReduceCmd:MongoDocument= new MongoDocument();
			if (collectionName != null) mapReduceCmd.addKeyValuePair("mapreduce", collectionName);
			if (map != null) mapReduceCmd.addKeyValuePair("map", map);
			if (reduce != null) mapReduceCmd.addKeyValuePair("reduce", reduce);
			if (query != null) mapReduceCmd.addKeyValuePair("query", query);
			if (sort != null) mapReduceCmd.addKeyValuePair("sort", sort);
			if (limit != 0) mapReduceCmd.addKeyValuePair("limit", limit);
			if (out != null) mapReduceCmd.addKeyValuePair("out", out);
			if (finalize != null) mapReduceCmd.addKeyValuePair("finalize", finalize);
			if (scope != null) mapReduceCmd.addKeyValuePair("scope", scope);
			if (jsMode != false) mapReduceCmd.addKeyValuePair("jsMode", jsMode);
			if (verbose != false) mapReduceCmd.addKeyValuePair("verbose", verbose);
			// var cmd:MongoDocument = new MongoDocument("group", mapReduceCmd);
			
			runQueryCommand(mapReduceCmd, responder,  new MapReduceResponseInterpreter());
		}
		
		/**
		 * Do aggregation on documents. More on aggregation framework can be found on the MongoDB Documentation.
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param pipeline (MongoAggregationPipeline) : the pipeline of aggregation command. See MongoAggregationPipeline
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
		 * @see MongoAggregationPipeline
		 */
		public function aggregate(collectionName:String, pipeline:MongoAggregationPipeline, responder:MongoResponder=null):void {
			log.info("Calling aggregate collectionName="+collectionName+" pipeline="+pipeline+" responder="+responder);
			if (pipeline == null) pipeline = new MongoAggregationPipeline();
			var cmd:MongoDocument = new MongoDocument("aggregate", collectionName).addKeyValuePair("pipeline", pipeline.tabPipelineOperators);
			
			runQueryCommand(cmd, responder, new AggregationResponseInterpreter());
			log.info("EndIf aggregate");
		}
		
		protected function prepareQuery(collectionName:String, query:MongoDocumentQuery, returnFields:MongoDocument=null, numberToSkip:uint=0, numberToReturn:int=0, tailableCursor:Boolean=false, slaveOk:Boolean=false, noCursorTimeout:Boolean=false, awaitData:Boolean=false, exhaust:Boolean=false, partial:Boolean=false ):MongoMsgQuery {
			log.debug("Calling prepareQuery collectionName="+collectionName+" query="+query.toString()+" returnFields="+ObjectUtil.toString(returnFields)+" numberToSkip="+numberToSkip+" numberToReturn="+numberToReturn);
			var flags:uint = tailableCursor ? 2:0 +
				slaveOk ? 4:0 +
				noCursorTimeout ? 16:0 +
				awaitData ? 32:0 +
				exhaust ? 64:0 +
				partial ? 128:0;
			
			var msg:MongoMsgQuery = new MongoMsgQuery(_driver.databaseName, collectionName, numberToSkip, numberToReturn, tailableCursor, slaveOk, noCursorTimeout, awaitData, exhaust, partial);
			msg.query = query;
			msg.returnFieldsSelector = returnFields;
			
			log.debug("EndOf prepareQuery");
			return msg;
		}
		
		/**
		 * Called when a socket is available in the pool
		 */
		protected function onFreeSocket(event:EventSocketPool):void {
			log.evt("Calling onFreeSocket : A free socket is available in the pool");
			popAndSendMessage();
			log.debug("EndOf onFreeSocket : A free socket is available in the pool");
		}
		
		protected function popAndSendMessage():void {
			log.debug("Calling popAndSendMessage : trying to pop and send a message");
			if (!_started) {
				log.info("popAndSendMessage : the runner is not started. So wait ...");
				return ;
			}
			// get the first awaiting message
			var msg:Object = _awaitingMessages.pop();
			
			// if awaiting list is not empty, pop and send message
			if (msg == null) {
				log.debug("No awaiting messages");
				return ;
			}
			
			// gets a socket
			var socket:TimedSocket = null;
			try {
				socket = getConnectedSocket();
			} catch (e:ExceptionJMCNetMongoDB) {
				log.warn("There was waiting message that cannot be send. exception="+e.message+" msg="+ObjectUtil.toString(msg));
			}
			
			// if no more socket -> repush the message
			if (socket == null) {
				log.debug("There is no more socket free.");
				_awaitingMessages.push(msg);
				return ;
			}
			
			// sending
			sendMessageToSocket(msg as MongoMsgAbstract, socket);
			log.debug("EndOf popAndSendMessage : the socket #"+socket.id+" has been used for pulling a waiting message.");
		}
		
		protected function sendMessageToSocket(msg:MongoMsgAbstract, socket:TimedSocket):void {
			// send the message by writing BSON into socket
			var bson:ByteArray = msg.toBSON();
			log.evt("Calling sendMessageToSocket socket #"+socket.id+" msg='"+msg.toString()+"'");
			if (BSONEncoder.logBSON) log.debug("sendMessageToSocket sending msg : "+HelperByteArray.byteArrayToString(bson));
			
			
			if (!msg.needResponse) {
				log.debug("Write message in socket #"+socket.id);
				socket.writeBytes(bson);
				socket.flush();
				
				log.debug("There no answer to wait for. Check if safe mode.");
				// There is no DB answer
				// safeMode ?
				checkSafeModeAndReleaseSocket(msg.responder, socket);
			}
			else {
				// lookup the answer
				log.debug("There will be an answer to wait for, so prepare the reader. socket #"+socket.id);
				if (msg.responder == null) msg.responder = new MongoResponder(onResponseQueryReady);
				new MongoResponseReader(socket, msg.responder, _driver.pool);
				log.debug("Write message in socket #"+socket.id);
				socket.writeBytes(bson);
				socket.flush();
			}
		}
		
		protected function getConnectedSocket():TimedSocket {
			if (!_driver.isConnecte()) {
				log.warn("Not connected to MongoDB");
				throw new ExceptionJMCNetMongoDB("Not connected to MongoDB");
			}
			var socket:TimedSocket = _driver.pool.getFreeSocket();
			// When there is no more free socket, just wait...
			
			return socket;
		}
		
		protected function checkSafeModeAndReleaseSocket(responder:MongoResponder, socket:TimedSocket):void {
			log.debug("Calling checkSafeMode responder="+responder+" socket #"+socket.id);
			if (_driver.safeMode > 0) {
				// Safe mode
				log.debug("We are in safe Mode");
				var msg:MongoMsgQuery = prepareQuery("$cmd", new MongoDocumentQuery(_driver.lastErrorDoc), null, 0, -1);
				msg.responder = responder == null ? new MongoResponder(onResponseLastError):responder;
				msg.responder.responseInterpreter = new GetLastErrorResponseInterpreter();
				sendMessageToSocket(msg, socket);
				log.debug("Waiting for getLastError (safeMode) answer");
			}
			else {
				log.debug("We are not in safe Mode -> release the socket");
				releaseSocket(socket);
			}
		}
		
		protected function releaseSocket(socket:TimedSocket):void {
			_driver.pool.releaseSocket(socket);
		}
		
		protected function prepareMsgForSending(msg:MongoMsgAbstract, responder:MongoResponder):void {
			log.debug("Calling prepareMsgForSending");
			
			msg.responder = responder;
			var socket:TimedSocket=null;
			if (_started) {
				socket = getConnectedSocket();
			}
			else {
				log.info("Runner is not started");
			}
			
			if (socket != null) {
				log.debug("There is an available socket and runner is started -> sends directly in socket #"+socket.id);
				// Write into socket
				sendMessageToSocket(msg, socket);
			}
			else {
				log.info("There is no more available socket or runner is not started. We have to wait ...");
				_awaitingMessages.push(msg);
			}
			
			log.debug("End of prepareMsgForSending awaitingMessages.length="+_awaitingMessages.length);
		}
		
		override public function toString():String {
			return "[AbstractAsyncRunner databaseName="+_driver.databaseName+"]";
		}		
	}
}