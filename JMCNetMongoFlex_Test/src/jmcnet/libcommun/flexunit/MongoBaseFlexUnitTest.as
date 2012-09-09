package jmcnet.libcommun.flexunit
{
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import flexunit.framework.Assert;
	
	import jmcnet.libcommun.communs.helpers.HelperDate;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.logger.JMCNetLogger;
	import jmcnet.mongodb.documents.MongoAggregationPipeline;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.driver.MongoResponder;
	
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	
	import org.flexunit.asserts.*;
	import org.flexunit.async.Async;

	/**
	 * A basic MongoDB base flex unit class permitting driver initialization, connection, deconnection.
	 */
	public class MongoBaseFlexUnitTest
	{		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoBaseFlexUnitTest);
		
		/**
		 * Connect manually the test class. For this, you must call the connect method
		 */
		public static const CONNECT_TYPE_MANUALLY:uint=0;
		/**
		 * Connect automatically the test class on the setUp method. The disconnection is done in the tearDown method.
		 */
		public static const CONNECT_TYPE_ON_SET_UP:uint=2;
		
		// Store this object in a MongoDB instance
		public static var driver:JMCNetMongoDBDriver = new JMCNetMongoDBDriver();
		// The name of the collection to clean after test. Null is no clean is required
		private static var collectionToClean:String=null;
		private static var connectType:uint=CONNECT_TYPE_MANUALLY;
		
		private static var instance:MongoBaseFlexUnitTest=null;
		
		public function MongoBaseFlexUnitTest(connectType:uint=CONNECT_TYPE_MANUALLY, collectionToClean:String=null, databaseName:String=null, username:String=null, password:String=null, server:String=null, port:uint=0, writeConcern:uint=JMCNetMongoDBDriver.SAFE_MODE_NORMAL, socketPoolMin:uint=1, socketPoolMax:uint=2):void {
			JMCNetLogger.setLogEnabled(true, false);
			JMCNetLogger.setLogLevel(JMCNetLogger.DEBUG);
			
			instance = this;
			MongoBaseFlexUnitTest.connectType = connectType;
			MongoBaseFlexUnitTest.collectionToClean = collectionToClean;
			MongoBaseFlexUnitTest.driver.databaseName = databaseName;
			MongoBaseFlexUnitTest.driver.hostname = server;
			MongoBaseFlexUnitTest.driver.port = port;
			MongoBaseFlexUnitTest.driver.username = username;
			MongoBaseFlexUnitTest.driver.password = password;
			MongoBaseFlexUnitTest.driver.socketPoolMax = socketPoolMax;
			MongoBaseFlexUnitTest.driver.socketPoolMin = socketPoolMin;
			MongoBaseFlexUnitTest.driver.setWriteConcern(writeConcern);

			log.info("EndOf CTOR initialization");
		}
		
		public function setFineDebugLevel(logDocument:Boolean, logBSON:Boolean, logSocketPool:Boolean):void {
			driver.logBSON = logBSON;
			driver.logDocument = logDocument;
			driver.logSocketPool = logSocketPool;
		}
		
		[Before(async, timeout=10000)]
		public function setUp():void {
			log.info("Calling setUp");
			if (MongoBaseFlexUnitTest.connectType == CONNECT_TYPE_ON_SET_UP) {
				log.evt("Trying to connect test... Wait for 5 sec max.");
				// Wait for one second max, the event ConnectOK
				Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_CONNECTOK, onConnectOK, 5000, null, onTimeoutConnexion);
				driver.connect();
			}
			log.info("EndOf setUp");
		}
		
		public function onConnectOK(event:EventMongoDB, ... args):void {
			log.info("Calling onConnectOK : we are now connected");
			if (collectionToClean != null) {
				// clean up -> delete object
				log.info("Cleaning the test collection : "+collectionToClean);
				Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_RUN_COMMAND, onDropOK, 5000, null, onTimeoutConnexion);
				driver.dropCollection(collectionToClean);
			}
		}
		
		public function onDropOK(event:Event, ... args):void {
			log.info("Drop command succeed. Normal tests can begin.");
		}
		
		public function onTimeoutConnexion(event:Event, ... args):void {
			log.error("Error : we cannot connect to database in 5 sec !");
			fail("Error : we cannot connect to database in 5 sec !");
		}
		
		public static function onDisconnectOK(event:EventMongoDB, ... args):void {
			log.info("Calling onDisconnectOK : we are now disconnected");
		}
		
		public static function onAuthError(event:EventMongoDB):void {
			log.error("Error : authentication failed. Error is : "+event.toString());
		}
		
		public static function onCloseConnection(event:EventMongoDB):void {
			log.info("Connection with database is now closed");
		}
		
		[After(async, timeout=5000)]
		public function tearDown():void	{
			log.info("Calling tearDown");
			if (MongoBaseFlexUnitTest.connectType == CONNECT_TYPE_ON_SET_UP) {
				if (driver.isConnecte()) {
					// Wait for event one second max
					Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_CLOSE_CONNECTION, onDisconnectOK, 1000);
					if (collectionToClean != null) {
						// clean up -> delete object
						log.info("Cleaning the test collection : "+collectionToClean);
						driver.dropCollection(collectionToClean);
					}
					driver.disconnect();
				}
				else log.warn("WARNING : Database was not connected. Check if it is normal !");
			}
			log.info("End of tearDown");
		}
		
		public function onDisconnectOK(event:EventMongoDB, ... args):void {
			log.info("Calling onDisconnectOK : we are now disconnected");
		}
				
		[Test(async, timeout=5000)]
		public function testFlexUnitEnv():void {
			log.debug("Calling testFlexUnitEnv");
			// Just do nothing. It's only to verify that setUp is allright.
			assertTrue(true);
			log.debug("EndOf testFlexUnitEnv");
		}
		
		/**
		 * Wait for one second
		 */
		public function waitOneSecond():void {
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait one second");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
//			t.addEventListener(TimerEvent.TIMER, voidFunction);
		}
		
		/**
		 * A void function callable by timer or other Async.handleEvent
		 */
		public function voidFunction(event:Event, ... args):void {
			log.debug("Calling voidFunction");
			log.debug("EndOf voidFunction");
		}
	}
}