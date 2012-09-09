package junit
{
	import jmcnet.libcommun.flexunit.MongoBaseFlexUnitTest;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.logger.JMCNetLogger;
	import jmcnet.mongodb.documents.DBRef;
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

	public class MongoSyncRunnerSafeModeTest extends MongoBaseFlexUnitTest
	{		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoSyncRunnerSafeModeTest);
		
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
		
		public function MongoSyncRunnerSafeModeTest() {
			setFineDebugLevel(false, false, false);
			super(CONNECT_TYPE_ON_SET_UP, "testu", DATABASENAME, USERNAME, PASSWORD, SERVER, PORT, JMCNetMongoDBDriver.SAFE_MODE_MAJORITY, 3, 3);
			
			JMCNetLogger.setLogLevel(JMCNetLogger.DEBUG);
			log.info("EndOf MongoSyncRunnerSafeModeTest CTOR initialization");
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
		private var _nbGoodCall:uint=0;
		[Test(async, timeout=5000)]
		public function testSyncRunnerBasics():void {
			log.info("------\nCalling testSyncRunnerBasics");
			
			// Without DBRef, send 4 commands synchronously. Those commands are supposed to be synchronously send else there will be KO
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// So write the doc composed of an ArrayCollection
			var syncRunner:MongoSyncRunner = new MongoSyncRunner(driver);
			syncRunner.createCollection("testu", new MongoResponder(onGoodCall, onBadCall));
			// badCall must not be called because safeMode is off
			syncRunner.insertDoc("testu", [doc1], new MongoResponder(onGoodCall, onBadCall));
			// badCall must not be called because safeMode is off
			syncRunner.updateDoc("testu",
				new MongoDocumentUpdate(
					MongoDocument.addKeyValuePair("author","bob"),
					MongoDocument.set("title","The new title")),
				new MongoResponder(onGoodCall, onBadCall), false, false);
			syncRunner.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedSyncRunnerBasics, onBadCall));
			
			Async.handleEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_COMPLETE, onRunnerCompleteSyncRunnerBasics);
			Async.failOnEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_ERROR);
			
			syncRunner.start();
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testSyncRunnerBasics");
		}
		
		public function onRunnerCompleteSyncRunnerBasics(event:EventMongoDB, ... args):void {
			log.info("Calling onRunnerCompleteSyncRunnerBasics");
			// Do something
			if (!_responseReceived) fail("We should go first into onResponseReceivedSyncRunnerBasics");
			assertEquals(3, _nbGoodCall);
			
			assertNotNull(event.result);
			var tabResponse:Array = event.result as Array;
			assertEquals(4, tabResponse.length);
			// tabResponse[0] contains the response to createCollection command
			var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
			log.debug("onRunnerCompleteSyncRunnerBasics response0="+response0.toString());
			assertTrue(response0.isOk);
			
			var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
			log.debug("onRunnerCompleteSyncRunnerBasics response1="+response1.toString());
			assertTrue(response1.isOk);
			
			var response2:MongoDocumentResponse = tabResponse[2] as MongoDocumentResponse;
			log.debug("onRunnerCompleteSyncRunnerBasics response2="+response2.toString());
			assertTrue(response2.isOk);
			
			var response3:MongoDocumentResponse = tabResponse[3] as MongoDocumentResponse;
			log.debug("onRunnerCompleteSyncRunnerBasics response3="+response3.toString());
			assertTrue(response3.isOk);
			
			var repDoc1:Object = response3.interpretedResponse[0];
			
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
		public function testSyncRunnerErrorContinue():void {
			log.info("------\nCalling testSyncRunnerErrorContinue");
			
			// Without DBRef, send 5 commands synchronously. Those commands are supposed to be synchronously send else there will be KO
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// So write the doc composed of an ArrayCollection
			var syncRunner:MongoSyncRunner = new MongoSyncRunner(driver, true);
			syncRunner.createCollection("testu", new MongoResponder(onGoodCall, onBadCall));
			syncRunner.createCollection("testu", new MongoResponder(onBadCall, onGoodCall)); // must be in error
			// badCall must not be called because safeMode is off
			syncRunner.insertDoc("testu", [doc1], new MongoResponder(onGoodCall, onBadCall)); // will be executed because continueOnError is true
			// badCall must not be called because safeMode is off
			syncRunner.updateDoc("testu",										  // will be executed because continueOnError is true
				new MongoDocumentUpdate(
					MongoDocument.addKeyValuePair("author","bob"),
					MongoDocument.set("title","The new title")),
				new MongoResponder(onGoodCall, onBadCall), false, false);
			syncRunner.queryDoc(												   // will be executed because continueOnError is true
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedSyncRunnerErrorContinue, onBadCall));
			
			Async.handleEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_ERROR, onRunnerErrorSyncRunnerErrorContinue);
			Async.failOnEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_COMPLETE);
			
			_responseReceived = false;
			_nbGoodCall = 0;
			syncRunner.start();
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testSyncRunnerErrorContinue");
		}
		
		public function onRunnerErrorSyncRunnerErrorContinue(event:EventMongoDB, ... args):void {
			log.info("Calling onRunnerErrorSyncRunnerErrorContinue");
			// Do something
			if (!_responseReceived) fail("We should go first into onRunnerErrorSyncRunnerErrorContinue");
			
			assertEquals(4, _nbGoodCall);
			
			assertNotNull(event.result);
			var tabResponse:Array = event.result as Array;
			assertEquals(5, tabResponse.length);
			// tabResponse[0] contains the response to createCollection command
			var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
			assertTrue(response0.isOk);
			
			var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
			assertFalse(response1.isOk);
			assertEquals("collection already exists", response1.errorMsg);
			
			var response2:MongoDocumentResponse = tabResponse[2] as MongoDocumentResponse;
			assertTrue(response2.isOk);
			
			var response3:MongoDocumentResponse = tabResponse[3] as MongoDocumentResponse;
			assertTrue(response3.isOk);
			
			var response4:MongoDocumentResponse = tabResponse[4] as MongoDocumentResponse;
			assertTrue(response4.isOk);
			var repDoc1:Object = response4.interpretedResponse[0];
			
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
		
		[Test(async, timeout=5000)]
		public function testSyncRunnerWithBDRef():void {
			log.info("------\nCalling testSyncRunnerWithBDRef");
			
			// Without DBRef, send 5 commands synchronously. Those commands are supposed to be synchronously send else there will be KO
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 5;
			
			// So write the doc composed of an ArrayCollection
			var syncRunner:MongoSyncRunner = new MongoSyncRunner(driver, true);
			syncRunner.createCollection("testu", new MongoResponder(onGoodCall, onBadCall));
			// badCall must not be called because safeMode is off
			// We are connected, so write the doc composed of an ArrayCollection
			doc1.doc2Ref = new DBRef("testu", doc2._id);
			syncRunner.insertDoc("testu", [doc1], new MongoResponder(onGoodCall, onBadCall)); // will be executed 
			syncRunner.insertDoc("testu", [doc2], new MongoResponder(onGoodCall, onBadCall)); // will be executed 
			syncRunner.queryDoc(												   // will be executed because continueOnError is true
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedSyncRunnerWithBDRef, onBadCall));
			
			Async.handleEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_COMPLETE, onRunnerCompleteSyncRunnerWithBDRef);
			Async.failOnEvent(this, syncRunner, MongoSyncRunner.EVT_RUNNER_ERROR);
			
			_responseReceived = false;
			_nbGoodCall = 0;
			syncRunner.start();
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testSyncRunnerWithBDRef");
		}
		
		public function onRunnerCompleteSyncRunnerWithBDRef(event:EventMongoDB, ... args):void {
			log.info("Calling onRunnerCompleteSyncRunnerWithBDRef");
			// Do something
			if (!_responseReceived) fail("We should go first into onRunnerCompleteSyncRunnerWithBDRef");
			
			assertEquals(3, _nbGoodCall);
			
			assertNotNull(event.result);
			var tabResponse:Array = event.result as Array;
			assertEquals(4, tabResponse.length);
			// tabResponse[0] contains the response to createCollection command
			var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
			assertTrue(response0.isOk);
			
			var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
			assertTrue(response1.isOk);
			
			var response2:MongoDocumentResponse = tabResponse[2] as MongoDocumentResponse;
			assertTrue(response2.isOk);
			
			var response3:MongoDocumentResponse = tabResponse[3] as MongoDocumentResponse;
			assertTrue(response3.isOk);
			var repDoc1:Object = response3.interpretedResponse[0];
			
			assertEquals(doc1.title, repDoc1.title);
			assertEquals(doc1.author, repDoc1.author);
			assertEquals(doc1.other.foo, repDoc1.other.foo);
			
			// Check DBRef value
			var dbref:DBRef = repDoc1.doc2Ref;
			assertEquals("testu", dbref.collectionName);
			assertEquals(doc2._id.toString(), dbref.id);
			assertNull(dbref.databaseName);
			// Check that DBRef has been flushed
			assertNotNull(dbref.value);
			assertEquals(doc2.title, dbref.value.title);
			assertEquals(doc2.author, dbref.value.author);
			assertEquals(doc2.pageViews, dbref.value.pageViews);
			assertEquals(doc2.comments.length, dbref.value.comments.length);
			assertEquals(doc2.other.foo, dbref.value.other.foo);
			
			log.info("EndOf onRunnerCompleteSyncRunnerWithBDRef");
		}
		
		public function onResponseReceivedSyncRunnerWithBDRef(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedSyncRunnerWithBDRef responseDoc="+rep+" token="+token);
			
			_responseReceived = true;
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			
			assertEquals(doc1.title, repDoc1.title);
			assertEquals(doc1.author, repDoc1.author);
			assertEquals(doc1.other.foo, repDoc1.other.foo);
			
			// Check DBRef value
			var dbref:DBRef = repDoc1.doc2Ref;
			assertEquals("testu", dbref.collectionName);
			assertEquals(doc2._id.toString(), dbref.id);
			assertNull(dbref.databaseName);
			// Check that DBRef has been flushed
			assertNotNull(dbref.value);
			assertEquals(doc2.title, dbref.value.title);
			assertEquals(doc2.author, dbref.value.author);
			assertEquals(doc2.pageViews, dbref.value.pageViews);
			assertEquals(doc2.comments.length, dbref.value.comments.length);
			assertEquals(doc2.other.foo, dbref.value.other.foo);
			log.info("EndOf onResponseReceivedSyncRunnerWithBDRef");
		}
		
		public function onBadCall(rep:MongoDocumentResponse, token:*):void {
			fail("We should not be there...");
		}
		
		public function onGoodCall(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onGoodCall response="+rep.toString());
			_nbGoodCall++;
		}
	}
}