package jmcnet.mongodb.driver
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.net.Responder;
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	
	import jmcnet.libcommun.communs.structures.FifoStack;
	import jmcnet.libcommun.communs.structures.HashTable;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.security.MD5;
	import jmcnet.libcommun.socketpool.EventSocketPool;
	import jmcnet.libcommun.socketpool.PoolInfos;
	import jmcnet.libcommun.socketpool.SocketPool;
	import jmcnet.libcommun.socketpool.SocketPoolAuthenticated;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.bson.BSONDecoder;
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
	import jmcnet.mongodb.messages.interpreter.CountResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.DistinctResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.GetLastErrorResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.GroupResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.MapReduceResponseInterpreter;
	import jmcnet.mongodb.messages.interpreter.MongoResponseInterpreterInterface;
	
	import mx.utils.ObjectUtil;
	
	/**
	 * The Driver class. A driver instance is dedicated to one database.
	 * @param hostname (String) : the MongoDB server's hostname,
	 * @param port (uint) : the MongoDB server's port. Default value is 27017,
	 * @param databaseName (String) : the database's name this driver is dedicated to,
	 * @param socketPoolMin (uint) : the min number of connection in the pool. Default value is 10,
	 * @param socketPoolMax (uint) : the max number of connection in the pool. Default value is 50,
	 * @param socketTimeOutMs (uint) : the socket timeout in milliseconds. Default value is 10 seconds,
	 * @param username (String) : username used for authentication. If null, driver is in non authenticate mode. Default value is null,
	 * @param password (String) : password of the user for authentication. Default value is null,
	 * @param logBSON (Boolean) : if true trace BSON encoding/decoding. Default value is false,
	 * @param logDocument (Boolean) : if true trace all Document manipulation. Default value is false.
	 */
	[Event(name=EVT_CONNECTOK, type="newjmcnetds.EventMongoDB")] // dispatched when driver is connected and authenticated in auth mode
	[Event(name=EVT_AUTH_ERROR, type="newjmcnetds.EventMongoDB")] // dispatched when authentication failed
	[Event(name=EVT_CLOSE_CONNECTION, type="newjmcnetds.EventMongoDB")] // dispatched when all connection are closed
	[Event(name=EVT_LAST_ERROR, type="newjmcnetds.EventMongoDB")]  // dispatched when a response to a getLastError command is received
	[Event(name=EVT_RUN_COMMAND, type="newjmcnetds.EventMongoDB")] // dispatched when a response to a runCommand is received an no responder has been provided
	[Event(name=EVT_RESPONSE_RECEIVED, type="newjmcnetds.EventMongoDB")] // dispatched when a response to a query is received an no responder has been provided
	public class JMCNetMongoDBDriver extends EventDispatcher
	{
		public var hostname:String="";
		public var port:uint=27017;
		public var databaseName:String="";
		public var socketPoolMin:uint=2;
		public var socketPoolMax:uint=5;
		public var socketTimeOutMs:uint=10000;
		public var username:String=null;
		public var password:String=null;
		
		/**
		 * Fine debug level for BSON Encoder / Decoder
		 */
		public var logDocument:Boolean=false;
		/**
		 * Fine debug level for MongoDocument manipulation
		 */
		public var logBSON:Boolean=false;
		/**
		 * Fine debug level for Socket manipulation
		 */
		public var logSocketPool:Boolean=false;
		
		// The socket pool
		private var _pool:SocketPoolAuthenticated;
		
		// The waiting for pool commands
		[ArrayElementType("jmcnet.mongodb.messages.MongoMsgAbstract")]
		private var _awaitingMessages:FifoStack = new FifoStack();
		
		// The list of drivers instanciated stored by databaseName
		private static var _lstDrivers:HashTable = new HashTable();
		
		// Safe Mode parameters
		public static const SAFE_MODE_MAJORITY:int=-2;
		public static const SAFE_MODE_NONE:int=-1;
		public static const SAFE_MODE_NORMAL:int=0;
		public static const SAFE_MODE_SAFE:int=1;
		public static const SAFE_MODE_REPLICAS_SAFE:int=2;
		
		public static const EVT_CONNECTOK:String="connectOK";
		public static const EVT_AUTH_ERROR:String="authenticationError";
		public static const EVT_CLOSE_CONNECTION:String="closeConnection";
		public static const EVT_LAST_ERROR:String="lastError";
		public static const EVT_RUN_COMMAND:String="runCommand";
		public static const EVT_RESPONSE_RECEIVED:String="responseReceived";
		
		
		private var _w:int=0;
		private var _wTimeOutMs:int=0;
		private var _fsync:Boolean=false;
		private var _j:Boolean=false;
		private var _lastErrorDoc:MongoDocument;
		private var _firstAuthenticationError:Boolean = true;
		
		// The depth max for fetching DBRef
		private static var _maxDBRefDepth:uint=0;
		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(JMCNetMongoDBDriver);
		
		/**
		 * Build one MongoDB Driver. You must instanciate, one driver per database.
		 * Public parameters should be set :
		 *   - hostname, port : the hostname and port of Mongo DB,
		 *   - databaseName : the name of the database,
		 * 
		 * Those public parameters can be optionnaly be set :
		 *   - socketPoolMin : the min number of connected socket to DB. Keep in mind that all communication with MongoDB are asynchronous. So provided sufficient min value. Defaut value is 10,
		 *   - socketPoolMax : the max number of connected socket to DB. Default value is 50,
		 *   - socketTimeOutMs : the timeout for listen for an answer from DB. After this time, if there was no response, socket is closed and a new one is open,
		 *   - username : the username in authenticate mode. If provided, this turn the authenticate mode on,
		 *   - password : the password in authenticate mode. 
		 */
		public function JMCNetMongoDBDriver() {
			log.info("CTOR databaseName="+databaseName);
			setWriteConcern();
		}
		
		/**
		 * Connect to MongoDB and register the driver for the databaseName. If username and password are supplied, each connection try to authenticated.
		 */
		public function connect(username:String=null, password:String=null):void {
			if (username != null) this.username = username;
			if (password != null) this.password = password;
			
			log.info("databaseName="+databaseName+" connect username="+this.username+" password="+(this.password == null ? "null":"xxxxxxxx"));
			
			// register driver
			registerDriver();
			
			log.debug("logBSON="+logBSON+" logDocument="+logDocument);
			BSONEncoder.logBSON = logBSON;
			BSONDecoder.logBSON = logBSON;
			MongoDocument.logDocument = logDocument;
			SocketPool.logSocketPool = logSocketPool;
			
			if (_pool == null) _pool = new SocketPoolAuthenticated(socketPoolMin, socketPoolMax, socketTimeOutMs);
			_pool.addEventListener(SocketPool.EVENT_POOL_DISCONNECTED,onPoolClose);
			_pool.addEventListener(SocketPool.EVENT_POOL_CONNECTED, onPoolOpen);
			if (this.username != null) {
				// Connect with authentication callback
				_pool.connect(hostname, port, doAuthentication);
			}
			else {
				// Connect without authentication callback
				_pool.connect(hostname, port);
			}
			
		}
		
		private function registerDriver():void {
			JMCNetMongoDBDriver._lstDrivers.addItem(databaseName, this);
		}
		
		/**
		 * Find a driver in the list of connected driver. If databaseName is null, the first driver in the list is returned (usefull for mono-driver applications)
		 * @param databaseName (String) : the name of the database's driver to find or null to return the first one.
		 * @return driver The JMCNetMongoDBDriver corresponding to databaseName or the first if databaseName is null
		 * @throws ExceptionJMCNetMongoDB if no driver if found for databaseName provided
		 */
		public static function findDriver(databaseName:String=null):JMCNetMongoDBDriver {
			log.debug("Calling findDriver databaseName="+databaseName);
			var ret:JMCNetMongoDBDriver=null;
			if (databaseName == null && _lstDrivers.length > 0) {
				ret = _lstDrivers.getItemAt(0);
			}
			else {
				ret = _lstDrivers.getItem(databaseName);
			}
			
			if (ret == null) {
				throw new ExceptionJMCNetMongoDB("Error : driver for databaseName='"+databaseName+"' unknown. Notice that drivers are unknown until there are not connected for first time. See connect()");
			}
			
			log.debug("EndOf driver="+ret);
			return ret;
		}
		
		/**
		 * Do authentication on a connected socket
		 */
		private function doAuthentication(socket:TimedSocket):void {
			log.debug("Calling doAuthentication socket #"+socket.id);
			
			// send getnonce command to get the nonce
			var msg:MongoMsgQuery = prepareQuery("$cmd", new MongoDocumentQuery(new MongoDocument("getnonce",1)), null, 0, 1);
			msg.responder = new MongoResponder(onGetNonce, onErrorCallback);
			
			sendMessageToSocket(msg, socket);			
		}
		
		/**
		 * We receive the nonce, let's do authentication
		 */
		private function onGetNonce(response:MongoDocumentResponse, token:*):void {
			log.evt("Calling onGetNonce response="+response.toString()+" socket #"+response.socket.id);
			
			if (response.documents.length < 1 || response.documents[0].getValue("nonce") == null) {
				var errmsg:String="Error while authenticating. Nonce value not received. Check MongoDB logs. Response is : '"+response.toString()+"'";
				log.warn(errmsg);
				if (_firstAuthenticationError) {
					_firstAuthenticationError = false;
					throw new ExceptionJMCNetMongoDB(errmsg);
				}
			}
			var nonce:String = response.documents[0].getValue("nonce");
			
			// send getnonce command to get the nonce
			var doc:MongoDocumentQuery = new MongoDocumentQuery();
			doc.addQueryCriteria("authenticate", 1);
			doc.addQueryCriteria("user", username);
			doc.addQueryCriteria("nonce", nonce);
			var pwd:String=MD5.encrypt( username + ":mongo:" + password );
			log.debug("pwd="+pwd);
			var digest:String = MD5.encrypt(nonce + username +  pwd);
			doc.addQueryCriteria("key", digest);
			var msg:MongoMsgQuery = prepareQuery("$cmd", doc, null, 0, 1);
			
			msg.responder = new MongoResponder(onGetAuthentResponse, onErrorCallback);
			
			sendMessageToSocket(msg, response.socket);	
		}
		
		private function onErrorCallback(response:MongoDocumentResponse, token:*):void {
			log.error("Error : "+response.errorMsg);
		}
		
		/**
		 * We receive the authent response
		 */
		private function onGetAuthentResponse(response:MongoDocumentResponse, token:*):void {
			log.evt("Calling onGetAuthentResponse response="+response.toString()+" socket #"+response.socket.id);
			if (response.documents.length < 1 || response.documents[0].getValue("ok") == null) {
				var errmsg:String="Error while authenticating. Authentication response not received. Check MongoDB logs. Response is : '"+response.toString()+"'";
				log.warn(errmsg);
				throw new ExceptionJMCNetMongoDB(errmsg);
			}
			var ok:uint = response.documents[0].getValue("ok");
			if (ok != 1) {
				errmsg = response.documents[0].getValue("errmsg");
				var msg:String="Error while authenticating. Authentication failed. Error is : '"+errmsg+"'";
				log.warn(errmsg);
				if (_firstAuthenticationError) {
					_firstAuthenticationError = false;
					log.evt("Dispatch evt EVT_AUTH_ERROR");
					this.dispatchEvent(new EventMongoDB(EVT_AUTH_ERROR));
				}
			}
			else {
				log.info("Authentication succeed -> put socket in free list.");
				// We send connectOK when authentication is ready, and only for the first socket
				_pool.onAuthenticateOk(response.socket);
			}
		}
		
		/**
		 * Set safeMode for writing.
		 * safeMode parameter :
		 *     -1 : don't even check for network error,
		 *      0 : don't call getLastError by default. This is the default value,
		 *      1 : call getLastError after update, insert or delete, but don't wait for slave,
		 *      2 : call getLastError and wait for slaves to complete operation.
		 * wTimeout : the time max to wait for an answer. If 0 the wait is infinite. Default value is 10 seconds.
		 * fsync : if true, wait for data to be written on disk.
		 * journal : if true, wait for the journalization of data
		 */
		public function setWriteConcern(safeMode:int=0, wTimeoutMs:uint=10000, fsync:Boolean=false, journal:Boolean=false):void {
			_w = safeMode;
			_wTimeOutMs = wTimeoutMs;
			_fsync = fsync;
			_j = journal;
			_lastErrorDoc = new MongoDocument("getLastError");
			if (_w != SAFE_MODE_MAJORITY) _lastErrorDoc.addKeyValuePair("w", _w);
			else _lastErrorDoc.addKeyValuePair("w", "majority");
			
			_lastErrorDoc.addKeyValuePair("j", _j);
			_lastErrorDoc.addKeyValuePair("wtimeout", _wTimeOutMs);
			_lastErrorDoc.addKeyValuePair("fsync", _fsync);
		}
		
		public function get safeMode():int { return _w;}
		public function get writeTimeouMs():int { return _wTimeOutMs;}
		public function get fsync():Boolean { return _fsync;}
		
		public function disconnect():void {
			log.evt("Calling disconnect");
			if (isConnecte()) {
				_pool.disconnect();
			}
		}
		
		/**
		 * Called when no more active socket are available.
		 */
		private function onPoolClose(event:Event):void {
			log.evt("Connection with MongoDB database has closed.");
			this.dispatchEvent(new EventMongoDB(EVT_CLOSE_CONNECTION));
		}
		
		/**
		 * Called when the first active socket is open.
		 */
		private function onPoolOpen(event:Event):void {
			log.evt("Connection with MongoDB database has opened.");
			// Call only in non auth mode. Else it is called when authentication succeed
			this.dispatchEvent(new EventMongoDB(EVT_CONNECTOK));
				
			// We listen for available sockets in the pool
			_pool.addEventListener(SocketPool.EVENT_FREE_SOCKET,onFreeSocket);
		}
		
		/**
		 * Check if the socket pool is connected (and authenticated in auth mode). ie has almost one connected socket.
		 */
		public function isConnecte():Boolean {
			if (_pool != null) return _pool.connected();
			else return false;
		}
		
		/**
		 * Insert one or more documents in a collection
		 * @param collectionName (String) : the name of the collection to insert into,
		 * @param documents (Array of Object or MongoDocument) : the objects to insert,
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 * @param continueOnError (Boolean) : true if must continue when there is an error. Default value is false.
		 */
		public function insertDoc(collectionName:String, documents:Array, safeResponder:MongoResponder=null, continueOnError:Boolean=true):void {
			log.info("Calling insertDoc collectionName="+collectionName+" safeResponder="+safeResponder+" continueOnError="+continueOnError+" documents="+ObjectUtil.toString(documents)); 
			
			var msg:MongoMsgInsert = new MongoMsgInsert(databaseName, collectionName, continueOnError);
			for each (var doc:Object in documents) {
				msg.addDocument(doc);
			}
			
			prepareMsgForSending(msg, safeResponder);
		}
		
		/**
		 * Query documents (ie. find, findOne, find.skip, find.limit).
		 * @param collectionName (String) : the name of the collection to query from,
		 * @param query (MongoDocumentQuery) : the query document,
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
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
		
		private function prepareQuery(collectionName:String, query:MongoDocumentQuery, returnFields:MongoDocument=null, numberToSkip:uint=0, numberToReturn:int=0, tailableCursor:Boolean=false, slaveOk:Boolean=false, noCursorTimeout:Boolean=false, awaitData:Boolean=false, exhaust:Boolean=false, partial:Boolean=false ):MongoMsgQuery {
			log.debug("Calling prepareQuery collectionName="+collectionName+" query="+query.toString()+" returnFields="+ObjectUtil.toString(returnFields)+" numberToSkip="+numberToSkip+" numberToReturn="+numberToReturn);
			var flags:uint = tailableCursor ? 2:0 +
				slaveOk ? 4:0 +
				noCursorTimeout ? 16:0 +
				awaitData ? 32:0 +
				exhaust ? 64:0 +
				partial ? 128:0;
			
			var msg:MongoMsgQuery = new MongoMsgQuery(databaseName, collectionName, numberToSkip, numberToReturn, tailableCursor, slaveOk, noCursorTimeout, awaitData, exhaust, partial);
			msg.query = query;
			msg.returnFieldsSelector = returnFields;

			log.debug("EndOf prepareQuery");
			return msg;
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
			
			var msg:MongoMsgGetMore = new MongoMsgGetMore(databaseName, collectionName, cursorID, numberToReturn);
			
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
		 */
		public function runCommand(command:MongoDocument, responder:MongoResponder=null, interpreter:MongoResponseInterpreterInterface=null ):void {
			log.info("Calling runCommand command="+command.toString()+" responder="+responder);
			var msg:MongoMsgCmd = new MongoMsgCmd(databaseName);
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
			runQueryCommand(_lastErrorDoc, responder == null ? new MongoResponder(onResponseLastError):responder, new GetLastErrorResponseInterpreter());
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

			var msg:MongoMsgUpdate = new MongoMsgUpdate(databaseName, collectionName, update, upsert, multiUpdate);
			
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
			
			var msg:MongoMsgDelete = new MongoMsgDelete(databaseName, collectionName, doc, singleRemove);
			
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
			runCommand(new MongoDocument("create",collectionName), safeResponder);
		}
		
		/**
		 * Drop a collection.
		 * @param collectionName (String) : the name of the collection to drop
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 */
		public function dropCollection(collectionName:String,  safeResponder:MongoResponder=null):void {
			log.info("Calling dropCollection collectionName="+collectionName+" safeResponder="+safeResponder);
			
			runCommand(new MongoDocument("drop",collectionName), safeResponder);
		}
		
		/**
		 * Rename a collection.
		 * @param collectionName (String) : the name of the collection to rename
		 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
		 */
		public function renameCollection(collectionName:String, newCollectionName:String, safeResponder:MongoResponder=null):void {
			log.info("Calling renameCollection collectionName="+collectionName+" newCollectionName="+newCollectionName+" safeResponder="+safeResponder);
			runCommand(new MongoDocument("renameCollection",databaseName+"."+collectionName).addKeyValuePair("to",databaseName+"."+newCollectionName), safeResponder);
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
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
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
		 * @param pipeline (MongoDocumentAggregationPipeline) : the pipeline of aggregation command. See MongoDocumentAggregationPipeline
		 * @param callback (Function) : the callback called when documents are ready to read. Default value is null,
		 * 
		 */
		public function aggregate(collectionName:String, pipeline:MongoAggregationPipeline, responder:MongoResponder=null):void {
			log.info("Calling aggregate collectionName="+collectionName+" pipeline="+pipeline+" responder="+responder);
			if (pipeline == null) pipeline = new MongoAggregationPipeline();
			var cmd:MongoDocument = new MongoDocument("aggregate", collectionName).addKeyValuePair("pipeline", pipeline.tabPipelineOperators);

			runQueryCommand(cmd, responder, new AggregationResponseInterpreter());
			log.info("EndIf aggregate");
		}

		
		/**
		 * Called when a socket is available in the pool
		 */
		private function onFreeSocket(event:EventSocketPool):void {
			log.debug("Calling onFreeSocket : A free socket is available in the pool");
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
				log.warn("There was waiting message that cannot be send exception="+e.message+" msg="+ObjectUtil.toString(msg));
			}
			
			// if no more socket -> repush the message
			if (socket == null) {
				log.warn("There is no more socket in onFreeSocket... Curious or see preceeding error.");
				_awaitingMessages.push(msg);
				return ;
			}
			
			// sending
			sendMessageToSocket(msg as MongoMsgAbstract, socket);
			log.debug("EndOf onFreeSocket : the socket #"+socket.id+" has been used for pulling a waiting message.");
		}
		
		private function sendMessageToSocket(msg:MongoMsgAbstract, socket:TimedSocket):void {
			// send the message by writing BSON into socket
			var bson:ByteArray = msg.toBSON();
			log.evt("Calling sendMessageToSocket socket #"+socket.id+" msg='"+msg.toString()+"'");
			if (logBSON) log.debug("sendMessageToSocket sending msg : "+HelperByteArray.byteArrayToString(bson));
			
			
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
				new MongoResponseReader(socket, msg.responder, _pool);
				log.debug("Write message in socket #"+socket.id);
				socket.writeBytes(bson);
				socket.flush();
			}
		}
		
		private function getConnectedSocket():TimedSocket {
			if (!isConnecte()) {
				log.warn("Not connected to MongoDB");
				throw new ExceptionJMCNetMongoDB("Not connected to MongoDB");
			}
			var socket:TimedSocket = _pool.getFreeSocket();
			// When there is no more free socket, just wait...
			
			return socket;
		}
		
		private function checkSafeModeAndReleaseSocket(responder:MongoResponder, socket:TimedSocket):void {
			log.debug("Calling checkSafeMode responder="+responder+" socket #"+socket.id);
			if (_w > 0) {
				// Safe mode
				log.debug("We are in safe Mode");
				var msg:MongoMsgQuery = prepareQuery("$cmd", new MongoDocumentQuery(_lastErrorDoc), null, 0, -1);
				msg.responder = responder == null ? new MongoResponder(onResponseLastError):responder;
				msg.responder.responseInterpreter = new GetLastErrorResponseInterpreter();
				sendMessageToSocket(msg, socket);
				log.debug("Waiting for getLastError (safeMode) answer");
			}
			else {
				log.debug("We are not in safe Mode -> release the socket");
				_pool.releaseSocket(socket);
			}
		}
		
		private function prepareMsgForSending(msg:MongoMsgAbstract, responder:MongoResponder):void {
			log.debug("Calling prepareMsgForSending");
			
			msg.responder = responder;
			var socket:TimedSocket=getConnectedSocket();
			
			if (socket != null) {
				log.debug("There is an available socket -> sends directly in socket #"+socket.id);
				// Write into socket
				sendMessageToSocket(msg, socket);
			}
			else {
				log.info("There is no more available socket. We have to wait ...");
				_awaitingMessages.push(msg);
			}
			
			log.debug("End of prepareMsgForSending awaitingMessages.length="+_awaitingMessages.length);
		}
		
		override public function toString():String {
			return "[JMCNetMongoDBDriver databaseName="+databaseName+" connected="+isConnecte()+"]";
		}
		
		/**
		 * returns the max depth when fetching nested DBRef. This applis to all drivers.
		 * - 0 means that driver won't try to deference automatically DBRefs.
		 * - 1 means that only the first level of DBRef are fetched. 
		 * @return uint
		 */   
		public static function get maxDBRefDepth():uint { return JMCNetMongoDBDriver._maxDBRefDepth; }
		
		/**
		 * Sets the max depth when fetching nested DBRef. This applis to all drivers.
		 * - 0 means that driver won't try to deference automatically DBRefs.
		 * - 1 means that only the first level of DBRef are fetched. 
		 * @return uint
		 */
		public static function set maxDBRefDepth(maxDBRefDepth:uint):void { JMCNetMongoDBDriver._maxDBRefDepth = maxDBRefDepth; }
	}
}