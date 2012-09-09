package junit
{
	import jmcnet.libcommun.flexunit.MongoBaseFlexUnitTest;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.logger.JMCNetLogger;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.documents.MongoDocumentUpdate;
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.driver.MongoResponder;
	import jmcnet.mongodb.runner.MongoSyncRunner;
	
	import org.flexunit.asserts.*;
	import org.flexunit.async.Async;

	public class MongoSyncRunnerTest extends MongoBaseFlexUnitTest
	{		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoSyncRunnerTest);
		
		/** For this test to be ok, you must have a mongodb server in auth mode with a database named "testDatabase" and a user name "testu" with password "testu"
		 *  The command to create this are the following :
		 *  use admin;
		 *  db.auth("root","password"); // log with the admin account
		 *  use testDatabase; // or create database is it doesn't exists
		 *  db.addUser("testu", "testu"); // add the testu user
		 */
		
		private static var DATABASENAME:String="testDatabase";
		private static var USERNAME:String="testu";
		private static var PASSWORD:String="testu";
		private static var SERVER:String="jmcsrv2";
		private static var PORT:uint=27017;
		
		public function MongoSyncRunnerTest() {
			setFineDebugLevel(false, false, false);
			super(CONNECT_TYPE_ON_SET_UP, "testu", DATABASENAME, USERNAME, PASSWORD, SERVER, PORT, JMCNetMongoDBDriver.SAFE_MODE_NORMAL, 3, 3);
			
			JMCNetLogger.setLogLevel(JMCNetLogger.DEBUG);
			log.info("EndOf MongoSyncRunnerTest CTOR initialization");
		}
		
		
		// To verify that all is allright
		[Test(async, timeout=5000)]
		override public function testFlexUnitEnv():void {
			log.debug("------\nCalling testFlexUnitEnv");
			
			super.testFlexUnitEnv();

			// Wait a sec for test to finish
			waitOneSecond();
		}
		
		private var doc1:Object = {
			_id : ObjectID.createFromString("doc1"),
			title : "this is my first title" ,
			author : "bob" ,
			posted : new Date(),
			pageViews : 5 ,
			tags : [ "fun" , "good" , "marvellous" ] ,
			comments : [
				{ author :"joe" , text : "this is cool" } ,
				{ author :"sam" , text : "this is bad" }
			],
			other : { foo : 10 }
		};
		
		private var doc2:Object = {
			_id : ObjectID.createFromString("doc2"),
			title : "this is my second title" ,
			author : "tony" ,
			posted : new Date(),
			pageViews : 6 ,
			tags : [ "fun" , "good" , "sad" ] ,
			comments : [
				{ author :"joe" , text : "this is cool" } ,
				{ author :"sam" , text : "this is bad" }
			],
			other : { foo : 5 }
		};
		
		private var doc3:Object = {
			_id : ObjectID.createFromString("doc3"),
			title : "this is my third title" ,
			author : "will smith" ,
			posted : new Date(),
			pageViews : 7 ,
			tags : [ "fun" , "sad" ] ,
			other : { foo : 2 }
		};
		
		private var _responseReceived:Boolean=false;
		[Test(async, timeout=5000)]
		public function testSyncRunnerBasics():void {
			log.info("------\nCalling testSyncRunnerBasics");
			
			// Without DBRef, send 4 commands synchronously. Those commands are supposed to be synchronously send else there will be KO
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// So write the doc composed of an ArrayCollection
			var syncRunner:MongoSyncRunner = new MongoSyncRunner(driver);
			syncRunner.createCollection("testu");
			// badCall must not be called because safeMode is off
			syncRunner.insertDoc("testu", [doc1], new MongoResponder(onBadCall));
			// badCall must not be called because safeMode is off
			syncRunner.updateDoc("testu",
				new MongoDocumentUpdate(
					MongoDocument.addKeyValuePair("author","bob"),
					MongoDocument.set("title","The new title")),
				new MongoResponder(onBadCall), false, false);
			syncRunner.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedSyncRunnerBasics));
			
			Async.handleEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_COMPLETE, onRunnerCompleteSyncRunnerBasics);
			Async.failOnEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_ERROR);
			
			_responseReceived = false;
			syncRunner.start();
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testSyncRunnerBasics");
		}
		
		public function onRunnerCompleteSyncRunnerBasics(event:EventMongoDB, ... args):void {
			log.info("Calling onRunnerCompleteSyncRunnerBasics");
			// Do something
			if (!_responseReceived) fail("We should go first into onResponseReceivedSyncRunnerBasics");
			
			assertNotNull(event.result);
			var tabResponse:Array = event.result as Array;
			assertEquals(2, tabResponse.length);
			// tabResponse[0] contains the response to createCollection command
			var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
			assertTrue(response0.isOk);
			
			var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
			assertTrue(response1.isOk);
			var repDoc1:Object = response1.interpretedResponse[0];
			
			assertEquals("The new title", repDoc1.title);
			assertEquals(doc1.author, repDoc1.author);
			assertEquals(doc1.other.foo, repDoc1.other.foo);
			log.info("EndOf onRunnerCompleteSyncRunnerBasics");
		}
		
		public function onResponseReceivedSyncRunnerBasics(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedDBRefOnSameCollection responseDoc="+rep+" token="+token);
			
			_responseReceived = true;
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];

			assertEquals("The new title", repDoc1.title);
			assertEquals(doc1.author, repDoc1.author);
			assertEquals(doc1.other.foo, repDoc1.other.foo);
			log.info("EndOf onResponseReceivedDBRefOnSameCollection");
		}
		
		[Test(async, timeout=5000)]
		public function testSyncRunnerErrorNoContinue():void {
			log.info("------\nCalling testSyncRunnerErrorNoContinue");
			
			// Without DBRef, send 5 commands synchronously. Those commands are supposed to be synchronously send else there will be KO
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// So write the doc composed of an ArrayCollection
			var syncRunner:MongoSyncRunner = new MongoSyncRunner(driver, false);
			syncRunner.createCollection("testu");
			syncRunner.createCollection("testu"); // this one must be in error
			// badCall must not be called because safeMode is off
			syncRunner.insertDoc("testu", [doc1], new MongoResponder(onBadCall));
			// badCall must not be called because safeMode is off
			syncRunner.updateDoc("testu",
				new MongoDocumentUpdate(
					MongoDocument.addKeyValuePair("author","bob"),
					MongoDocument.set("title","The new title")),
				new MongoResponder(onBadCall), false, false);
			syncRunner.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onBadCall));
			
			Async.handleEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_ERROR, onRunnerErrorSyncRunnerErrorNoContinue);
			Async.failOnEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_COMPLETE);
			
			_responseReceived = false;
			syncRunner.start();
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testSyncRunnerErrorNoContinue");
		}
		
		public function onRunnerErrorSyncRunnerErrorNoContinue(event:EventMongoDB, ... args):void {
			log.info("Calling onRunnerErrorSyncRunnerErrorNoContinue");
			// Do something
			assertNotNull(event.result);
			var tabResponse:Array = event.result as Array;
			assertEquals(2, tabResponse.length);
			// tabResponse[0] contains the response to createCollection command
			var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
			assertTrue(response0.isOk);
			
			var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
			assertFalse(response1.isOk);
			assertEquals("collection already exists", response1.errorMsg);

			log.info("EndOf onRunnerCompleteSyncRunnerErrorNoContinue");
		}
		
		[Test(async, timeout=5000)]
		public function testSyncRunnerErrorContinue():void {
			log.info("------\nCalling testSyncRunnerErrorContinue");
			
			// Without DBRef, send 4 commands synchronously. Those commands are supposed to be synchronously send else there will be KO
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// So write the doc composed of an ArrayCollection
			var syncRunner:MongoSyncRunner = new MongoSyncRunner(driver, true);
			syncRunner.createCollection("testu");
			syncRunner.createCollection("testu"); // must be in error
			// badCall must not be called because safeMode is off
			syncRunner.insertDoc("testu", [doc1], new MongoResponder(onBadCall)); // will be executed because continueOnError is true
			// badCall must not be called because safeMode is off
			syncRunner.updateDoc("testu",										  // will be executed because continueOnError is true
				new MongoDocumentUpdate(
					MongoDocument.addKeyValuePair("author","bob"),
					MongoDocument.set("title","The new title")),
				new MongoResponder(onBadCall), false, false);
			syncRunner.queryDoc(												   // will be executed because continueOnError is true
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedSyncRunnerErrorContinue));
			
			Async.handleEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_ERROR, onRunnerErrorSyncRunnerErrorContinue);
			Async.failOnEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_COMPLETE);
			
			_responseReceived = false;
			syncRunner.start();
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testSyncRunnerErrorContinue");
		}
		
		public function onRunnerErrorSyncRunnerErrorContinue(event:EventMongoDB, ... args):void {
			log.info("Calling onRunnerErrorSyncRunnerErrorContinue");
			// Do something
			if (!_responseReceived) fail("We should go first into onRunnerErrorSyncRunnerErrorContinue");
			
			assertNotNull(event.result);
			var tabResponse:Array = event.result as Array;
			assertEquals(3, tabResponse.length);
			// tabResponse[0] contains the response to createCollection command
			var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
			assertTrue(response0.isOk);
			
			var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
			assertFalse(response1.isOk);
			assertEquals("collection already exists", response1.errorMsg);
			
			var response2:MongoDocumentResponse = tabResponse[2] as MongoDocumentResponse;
			assertTrue(response2.isOk);
			var repDoc1:Object = response2.interpretedResponse[0];
			
			assertEquals("The new title", repDoc1.title);
			assertEquals(doc1.author, repDoc1.author);
			assertEquals(doc1.other.foo, repDoc1.other.foo);
			log.info("EndOf onRunnerErrorSyncRunnerErrorContinue");
		}
		
		public function onResponseReceivedSyncRunnerErrorContinue(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedDBRefOnSameCollection responseDoc="+rep+" token="+token);
			
			_responseReceived = true;
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			
			assertEquals("The new title", repDoc1.title);
			assertEquals(doc1.author, repDoc1.author);
			assertEquals(doc1.other.foo, repDoc1.other.foo);
			log.info("EndOf onResponseReceivedDBRefOnSameCollection");
		}
		
		public function onBadCall(rep:MongoDocumentResponse, token:*):void {
			fail("We should not be there...");
		}
	}
}