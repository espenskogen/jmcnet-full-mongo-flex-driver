package jmcnet.mongodb.driver
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.security.MD5;
	import jmcnet.libcommun.socketpool.SocketPool;
	import jmcnet.libcommun.socketpool.TimedSocket;
	import jmcnet.mongodb.bson.BSONDecoder;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.Cursor;
	import jmcnet.mongodb.documents.JavaScriptCode;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentDelete;
	import jmcnet.mongodb.documents.MongoDocumentKillCursors;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.documents.MongoDocumentUpdate;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;
	import jmcnet.mongodb.messages.MongoMsgDelete;
	import jmcnet.mongodb.messages.MongoMsgGetMore;
	import jmcnet.mongodb.messages.MongoMsgInsert;
	import jmcnet.mongodb.messages.MongoMsgKillCursors;
	import jmcnet.mongodb.messages.MongoMsgQuery;
	import jmcnet.mongodb.messages.MongoMsgUpdate;
	import jmcnet.mongodb.messages.MongoResponseReader;
	
	import mx.utils.ObjectUtil;
	
	[Event(name=EVT_CONNECTOK, type="newjmcnetds.EventMongoDB")]
	[Event(name=EVT_CLOSE_CONNECTION, type="newjmcnetds.EventMongoDB")]
	[Event(name=EVT_LAST_ERROR, type="newjmcnetds.EventMongoDB")]
	[Event(name=EVT_RUN_COMMAND, type="newjmcnetds.EventMongoDB")]
	[Event(name=EVT_RESPONSE_RECEIVED, type="newjmcnetds.EventMongoDB")]
	public class JMCNetMongoDBDriver extends EventDispatcher
	{
		public var hostname:String="";
		public var port:uint=27017;
		public var databaseName:String="";
		public var socketPoolMin:uint=10;
		public var socketPoolMax:uint=50;
		public var socketTimeOutMs:uint=10000;
		public var username:String=null;
		public var password:String=null;
		/**
		 * Fine debug level for BSON Encoder / Decoder
		 */
		public var logBSON:Boolean = false;
		/**
		 * Fine debug level for MongoDocument* manipulation
		 */
		public var logDocument:Boolean = false;
		
		private var _pool:SocketPool;
		
		// Safe Mode parameters
		public static const SAFE_MODE_MAJORITY:int=-2;
		public static const SAFE_MODE_NONE:int=-1;
		public static const SAFE_MODE_NORMAL:int=0;
		public static const SAFE_MODE_SAFE:int=1;
		public static const SAFE_MODE_REPLICAS_SAFE:int=2;
		
		public static const EVT_CONNECTOK:String="connectOK";
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
		
		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(JMCNetMongoDBDriver));
		
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
			setWriteConcern();
		}
		
		/**
		 * Connect to MongoDB. If username and password are supplied, each connection try to authenticated.
		 */
		public function connect(username:String=null, password:String=null):void {
			if (username != null) this.username = username;
			if (password != null) this.password = password;
			
			log.info("JMCNetMongoDBDriver::connect username="+this.username+" password="+(this.password == null ? "null":"xxxxxxxx"));
			
			if (_pool == null) _pool = new SocketPool(socketPoolMin, socketPoolMax, socketTimeOutMs);
			_pool.addEventListener("poolDisconnected",onPoolClose);
			_pool.addEventListener("poolConnected", onPoolOpen);
			if (this.username != null) {
				// Connect with authentication callback
				_pool.connect(hostname, port, doAuthentication);
			}
			else {
				// Connect without authentication callback
				_pool.connect(hostname, port);
			}
			
			BSONEncoder.logBSON = logBSON;
			BSONDecoder.logBSON = logBSON;
		}
		
		/**
		 * Do authentication on a connected socket
		 */
		private function doAuthentication(socket:TimedSocket):void {
			log.debug("Calling doAuthentication socket #"+socket.id);
			
			// send getnonce command to get the nonce
			sendQuery(socket, "$cmd", new MongoDocumentQuery(new MongoDocument("getnonce",1)), null, 0, 1);
			
			// lookup the answer
			log.debug("Waiting for answer");
			new MongoResponseReader(socket, onGetNonce, _pool);
		}
		
		/**
		 * We receive the nonce, let's do authentication
		 */
		private function onGetNonce(response:MongoDocumentResponse):void {
			log.evt("Calling onGetNonce response="+response.toString()+" socket #"+response.socket);
			
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
			sendQuery(response.socket, "$cmd", doc, null, 0, 1);
			
			// lookup the answer
			log.debug("Waiting for answer");
			new MongoResponseReader(response.socket, onGetAuthentResponse, _pool);
		}
		
		/**
		 * We receive the authent response
		 */
		private function onGetAuthentResponse(response:MongoDocumentResponse):void {
			log.evt("Calling onGetAuthentResponse response="+response.toString()+" socket #"+response.socket);
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
					throw new ExceptionJMCNetMongoDB(errmsg);
				}
			}
			else {
				log.info("Authentication succeed.");
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
			trace("Appel JMCNetMongoDBDriver::disconnect");
			if (isConnecte()) {
				_pool.disconnect();
			}
		}
		
		private function onPoolClose(event:Event):void {
			log.evt("Connection with MongoDB database has closed.");
			this.dispatchEvent(new EventMongoDB("closeConnection"));
		}
		
		private function onPoolOpen(event:Event):void {
			log.evt("Connection with MongoDB database has opened.");
			this.dispatchEvent(new EventMongoDB("connectOK")); 
		}
		
		public function isConnecte():Boolean {
			if (_pool != null) return _pool.connected();
			else return false;
		}
		
		private function getConnectedSocket():TimedSocket {
			if (!isConnecte()) {
				log.warn("Not connected to MongoDB");
				throw new ExceptionJMCNetMongoDB("Not connected to MongoDB");
			}
			var socket:TimedSocket = _pool.getFreeSocket();
			if (socket == null) {
				var errMsg:String="No more free socket connected to MongoDB. Pool min value too small ?";
				log.warn(errMsg);
				throw new ExceptionJMCNetMongoDB(errMsg);
			}
			
			return socket;
		}
		
		private function checkSafeModeAndReleaseSocket(safeCallback:Function, socket:TimedSocket):void {
			log.debug("Calling JMCNetMongoDBDriver::checkSafeMode safeCallback="+safeCallback+" socket #"+socket.id);
			if (_w > 0) {
				// Safe mode
				var q:MongoDocumentQuery = new MongoDocumentQuery(_lastErrorDoc);
				sendQuery(socket, "$cmd", q, null, 0, -1);
				log.debug("Waiting for getLastError (safeMode) answer");
				new MongoResponseReader(socket, safeCallback == null ? onResponseLastError:safeCallback, _pool);
			}
			else _pool.releaseSocket(socket);
		}
		
		/**
		 * Insert one or more document in a collection
		 */
		public function insertDoc(collectionName:String, documents:Array, safeCallback:Function=null, continueOnError:Boolean=true):void {
			log.info("Calling JMCNetMongoDBDriver::insert collectionName="+collectionName+" safeCallback="+safeCallback+" continueOnError="+continueOnError+" documents="+ObjectUtil.toString(documents)); 
			
			var socket:TimedSocket=getConnectedSocket();
			var msg:MongoMsgInsert = new MongoMsgInsert(databaseName, collectionName, continueOnError);
			for each (var doc:Object in documents) {
				msg.addDocument(doc);
			}
			
			// Write into socket
			var bson:ByteArray = msg.toBSON();
			if (logBSON) log.evt("JMCNetMongoDBDriver::insert sending msg : "+HelperByteArray.byteArrayToString(bson));
			socket.writeBytes(bson);
			socket.flush();
			
			// There is no DB answer
			// safeMode ?
			checkSafeModeAndReleaseSocket(safeCallback, socket);			
		}
		
		/**
		 * Query documents
		 */
		public function queryDoc(collectionName:String, query:MongoDocumentQuery, callback:Function=null, returnFields:MongoDocument=null, numberToSkip:uint=0, numberToReturn:int=0, tailableCursor:Boolean=false, slaveOk:Boolean=false, noCursorTimeout:Boolean=false, awaitData:Boolean=false, exhaust:Boolean=false, partial:Boolean=false ):void {
			log.info("Calling JMCNetMongoDBDriver::query collectionName="+collectionName+" query="+query.toString()+" returnFields="+ObjectUtil.toString(returnFields)+" numberToSkip="+numberToSkip+" numberToReturn="+numberToReturn);

			var socket:TimedSocket=getConnectedSocket();
			
			sendQuery(socket, collectionName, query, returnFields, numberToSkip, numberToReturn, tailableCursor, awaitData, exhaust, partial);
			
			// lookup the answer
			log.debug("Waiting for answer");
			if (callback == null) callback = onResponseQueryReady;
			new MongoResponseReader(socket, callback, _pool);
		}
		
		public function getMoreDoc(collectionName:String, cursorID:Cursor, callback:Function=null, numberToReturn:int=0):void {
			log.info("Calling JMCNetMongoDBDriver::getMore collectionName="+collectionName+" cursorID="+cursorID+" numberToReturn="+numberToReturn);
			
			var socket:TimedSocket=getConnectedSocket();
			
			var msg:MongoMsgGetMore = new MongoMsgGetMore(databaseName, collectionName, cursorID, numberToReturn);
			// Write into socket
			var bson:ByteArray = msg.toBSON();
			if (logBSON) log.evt("Sending getMore msg to database : "+HelperByteArray.byteArrayToString(bson));
			socket.writeBytes(bson);
			socket.flush();
			
			// lookup the answer
			log.debug("Waiting for answer");
			if (callback == null) callback = onResponseQueryReady;
			new MongoResponseReader(socket, callback, _pool);
		}
		
		private function sendQuery(socket:TimedSocket, collectionName:String, query:MongoDocumentQuery, returnFields:MongoDocument=null, numberToSkip:uint=0, numberToReturn:int=0, tailableCursor:Boolean=false, slaveOk:Boolean=false, noCursorTimeout:Boolean=false, awaitData:Boolean=false, exhaust:Boolean=false, partial:Boolean=false ):void {
			log.info("Calling JMCNetMongoDBDriver::sendQuery collectionName="+collectionName+" query="+query.toString()+" returnFields="+ObjectUtil.toString(returnFields)+" numberToSkip="+numberToSkip+" numberToReturn="+numberToReturn);
			var flags:uint = tailableCursor ? 2:0 +
				slaveOk ? 4:0 +
				noCursorTimeout ? 16:0 +
				awaitData ? 32:0 +
				exhaust ? 64:0 +
				partial ? 128:0;
			
			var msg:MongoMsgQuery = new MongoMsgQuery(databaseName, collectionName, numberToSkip, numberToReturn, tailableCursor, slaveOk, noCursorTimeout, awaitData, exhaust, partial);
			msg.query = query;
			msg.returnFieldsSelector = returnFields;
			
			// Write into socket
			var bson:ByteArray = msg.toBSON();
			if (logBSON) log.evt("Sending query msg to database : "+HelperByteArray.byteArrayToString(bson));
			socket.writeBytes(bson);
			socket.flush();
		}
		
		private function onResponseQueryReady (response:MongoDocumentResponse):void {
			log.debug("JMCNetMongoDBDriver::Calling onResponseReady response="+response.toString());
			// Dispatch the answer
			this.dispatchEvent(new EventMongoDB("responseReceived", response));
		}
		
		public function runCommand(command:MongoDocument, callback:Function=null ):void {
			log.info("Calling JMCNetMongoDBDriver::runCommand command="+command.toString()+" callback="+callback);
			var socket:TimedSocket = getConnectedSocket();
			
			var q:MongoDocumentQuery = new MongoDocumentQuery(command);
			sendQuery(socket, "$cmd", q, null, 0, -1);
			log.debug("Waiting for answer");
			if (callback == null) callback = onResponseRunCommandReady;
			new MongoResponseReader(socket, callback, _pool);
		}
		
		private function onResponseRunCommandReady (response:MongoDocumentResponse):void {
			log.info("JMCNetMongoDBDriver::Calling onResponseRunCommandReady response="+response.toString());
			// Dispatch the answer
			this.dispatchEvent(new EventMongoDB("runCommand", response));
		}
		
		public function getLastError(safeCallback:Function=null):void {
			log.info("Calling JMCNetMongoDBDriver::getLastError safeCallback="+safeCallback);
			runCommand(_lastErrorDoc, safeCallback == null ? onResponseLastError:safeCallback);
		}
		
		private function onResponseLastError(response:MongoDocumentResponse):void {
			log.debug("JMCNetMongoDBDriver::Calling onResponseLastError response="+response.toString());
			this.dispatchEvent(new EventMongoDB("lastError", response));
		}
		
		public function updateDoc(collectionName:String, update:MongoDocumentUpdate, safeCallback:Function = null, upsert:Boolean=false, multiUpdate:Boolean=false):void {
			log.info("Calling JMCNetMongoDBDriver::update collectionName="+collectionName+" safeCallback="+safeCallback+" update="+ObjectUtil.toString(update)+" upsert="+upsert+" multiUpdate="+multiUpdate);
			var socket:TimedSocket = getConnectedSocket();
			
			var msg:MongoMsgUpdate = new MongoMsgUpdate(databaseName, collectionName, update, upsert, multiUpdate);
			
			// Write into socket
			var bson:ByteArray = msg.toBSON();
			if (logBSON) log.evt("JMCNetMongoDBDriver::update sending msg : "+HelperByteArray.byteArrayToString(bson));
			socket.writeBytes(bson);
			socket.flush();
			
			// There is no answer
			
			// safeMode ?
			checkSafeModeAndReleaseSocket(safeCallback, socket);
		}
		
		public function deleteDoc(collectionName:String, doc:MongoDocumentDelete, safeCallback:Function = null, singleRemove:Boolean=false):void {
			log.info("Calling JMCNetMongoDBDriver::deleteDoc collectionName="+collectionName+" safeCallback="+safeCallback+" deleteDoc="+ObjectUtil.toString(doc)+" singleRemove="+singleRemove);
			var socket:TimedSocket = getConnectedSocket();
			
			var msg:MongoMsgDelete = new MongoMsgDelete(databaseName, collectionName, doc, singleRemove);
			
			// Write into socket
			var bson:ByteArray = msg.toBSON();
			if (logBSON) log.evt("JMCNetMongoDBDriver::deleteDoc sending msg : "+HelperByteArray.byteArrayToString(bson));
			socket.writeBytes(bson);
			socket.flush();
			
			// There is no answer
			
			// safeMode ?
			checkSafeModeAndReleaseSocket(safeCallback, socket);
		}
		
		public function killCursors(doc:MongoDocumentKillCursors, safeCallback:Function = null):void {
			log.info("Calling JMCNetMongoDBDriver::killCursor safeCallback="+safeCallback+" doc="+ObjectUtil.toString(doc));
			var socket:TimedSocket = getConnectedSocket();
			
			var msg:MongoMsgKillCursors = new MongoMsgKillCursors(doc);
			
			// Write into socket
			var bson:ByteArray = msg.toBSON();
			if (logBSON) log.evt("JMCNetMongoDBDriver::killCursors sending msg : "+HelperByteArray.byteArrayToString(bson));
			socket.writeBytes(bson);
			socket.flush();
			
			// There is no answer
			
			// safeMode ?
			checkSafeModeAndReleaseSocket(safeCallback, socket);
		}
		
		public function createCollection(collectionName:String,  safeCallback:Function = null):void {
			log.info("Calling JMCNetMongoDBDriver::createCollection collectionName="+collectionName+" safeCallback="+safeCallback);
			runCommand(new MongoDocument("create",collectionName), safeCallback);
		}
		
		public function dropCollection(collectionName:String,  safeCallback:Function = null):void {
			log.info("Calling JMCNetMongoDBDriver::dropCollection collectionName="+collectionName+" safeCallback="+safeCallback);
			runCommand(new MongoDocument("drop",collectionName), safeCallback);
		}
		
		public function count(collectionName:String, query:MongoDocument=null, callback:Function = null, skip:uint=0, limit:uint=0, snapshot:Boolean=false):void {
			log.info("Calling JMCNetMongoDBDriver::count collectionName="+collectionName+" callback="+callback+" skip="+skip+" limit="+limit+" snapshot="+snapshot);
			var cmd:MongoDocument = new MongoDocument("count",collectionName);
			if (query != null) cmd.addKeyValuePair("query", query);
			if (skip != 0) cmd.addKeyValuePair("skip", skip);
			if (limit != 0) cmd.addKeyValuePair("limit", limit);
			if (snapshot != false) cmd.addKeyValuePair("snapshot", snapshot);
			
			runCommand(cmd, callback);
		}
		
		public function distinct(collectionName:String, key:String, query:MongoDocument=null, callback:Function = null):void {
			log.info("Calling JMCNetMongoDBDriver::distinct collectionName="+collectionName+" key="+key+" callback="+callback);
			var cmd:MongoDocument = new MongoDocument("distinct",collectionName);
			if (key != null) cmd.addKeyValuePair("key", key);
			if (query != null) cmd.addKeyValuePair("query", query);
			
			runCommand(cmd, callback);
		}
		
		public function group(collectionName:String, key:MongoDocument, reduce:JavaScriptCode, initial:MongoDocument, callback:Function, keyf:JavaScriptCode=null, cond:MongoDocument=null, finalize:JavaScriptCode=null):void {
			log.info("Calling JMCNetMongoDBDriver::group collectionName="+collectionName+" key="+key+" reduce="+reduce+" initial="+initial+" callback="+callback+" keyf="+keyf+" cond="+cond+" finalize="+finalize);
			var grpCmd:MongoDocument= new MongoDocument();
			if (collectionName != null) grpCmd.addKeyValuePair("ns", collectionName);
			if (key != null) grpCmd.addKeyValuePair("key", key);
			if (reduce != null) grpCmd.addKeyValuePair("$reduce", reduce);
			if (initial != null) grpCmd.addKeyValuePair("initial", initial);
			if (keyf != null) grpCmd.addKeyValuePair("$keyf", keyf);
			if (cond != null) grpCmd.addKeyValuePair("cond", cond);
			if (finalize != null) grpCmd.addKeyValuePair("finalize", finalize);
			var cmd:MongoDocument = new MongoDocument("group", grpCmd); 
			
			runCommand(cmd, callback);
		}
		
		public function mapReduce(collectionName:String, map:JavaScriptCode, reduce:JavaScriptCode, out:MongoDocument, callback:Function,
								  query:MongoDocument=null, sort:MongoDocument=null, limit:uint=0, finalize:JavaScriptCode=null,
								  scope:MongoDocument=null, jsMode:Boolean=false, verbose:Boolean=false):void {
			log.info("Calling JMCNetMongoDBDriver::mapReduce collectionName="+collectionName+" map="+map+" reduce="+reduce+" out="+out+" callback="+callback+
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
			
			runCommand(mapReduceCmd, callback);
		}
	}
}