package junit
{
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import flexunit.framework.Assert;
	
	import jmcnet.libcommun.communs.helpers.HelperDate;
	import jmcnet.libcommun.flexunit.MongoBaseFlexUnitTest;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.logger.JMCNetLogger;
	import jmcnet.mongodb.documents.MongoAggregationPipeline;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.documents.MongoDocumentUpdate;
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.driver.MongoResponder;
	import jmcnet.mongodb.messages.interpreter.NullResponseInterpreter;
	
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	
	import org.flexunit.asserts.*;
	import org.flexunit.async.Async;

	public class MongoCommandsTest extends MongoBaseFlexUnitTest
	{		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoCommandsTest);
		
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
		
		public function MongoCommandsTest() {
			setFineDebugLevel(false, false, false);
			super(CONNECT_TYPE_ON_SET_UP, "testu", DATABASENAME, USERNAME, PASSWORD, SERVER, PORT, JMCNetMongoDBDriver.SAFE_MODE_SAFE, 2, 2);
			log.info("EndOf MongoCommandsTest CTOR initialization");
		}
		
		// To verify that all is allright
		[Test(async, timeout=5000)]
		override public function testFlexUnitEnv():void {
			log.debug("------ Calling testFlexUnitEnv");
			super.testFlexUnitEnv();
			
			// Wait a sec for test to finish
			waitOneSecond();
		}
		
		private var d1:Date = new Date(2022,08,25,0,0,0,0);
		private var d2:Date = new Date(); // asusme where are > 08/25/2012 and < 2022
		private var d3:Date = new Date(2011,08,25,0,0,0,0);
		private var doc1:Object = {
			title : "this is my first title" ,
			author : "bob" ,
			posted : d1,
			pageViews : 5 ,
			tags : [ "fun" , "good" , "marvellous" ] ,
			comments : [
				{ author :"joe" , text : "this is cool" } ,
				{ author :"sam" , text : "this is bad" }
			],
			other : { foo : 10 }
		};
		
		private var doc2:Object = {
			title : "this is my second title" ,
			author : "tony" ,
			posted : d2 ,
			pageViews : 6 ,
			tags : [ "fun" , "good" , "sad" ] ,
			comments : [
				{ author :"joe" , text : "this is cool" } ,
				{ author :"sam" , text : "this is bad" }
			],
			other : { foo : 5 }
		};
		
		private var doc3:Object = {
			title : "this is my third title" ,
			author : "bob" ,
			posted : d3,
			pageViews : 7,
			tags : [ "fun" , "good" ] ,
			other : { foo : 10 }
		};
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		
		[Test(async, timeout=5000)]
		public function testNullResponseInterpreter():void {
			log.debug("Calling testNullResponseInterpreter");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertNullResponseInterpreter));
			
			// Wait a sec for test to finish
			waitOneSecond();			
			log.debug("EndOf testNullResponseInterpreter");
		}
		
		public function onInsertNullResponseInterpreter(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertNullResponseInterpreter");
			// Find all docs
			// Ask for all object in collections but don't interprete them
			var nullResponder:MongoResponder = new MongoResponder(onResponseReceivedTestNullResponseInterpreter);
			nullResponder.responseInterpreter = new NullResponseInterpreter();
			driver.queryDoc("testu", null, nullResponder);
			
			log.debug("EndOf onInsertNullResponseInterpreter");
		}
		
		public function onResponseReceivedTestNullResponseInterpreter(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestNullResponseInterpreter responseDoc="+rep+" token="+token);
			
			assertEquals(3, rep.documents.length);
			assertNull(rep.interpretedResponse);
			log.debug("EndOf onResponseReceivedTestNullResponseInterpreter");
		}
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		[Test(async, timeout=5000)]
		public function testListCollections():void {
			log.debug("------ Calling testListCollections");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertListCollections));
			
			// Wait a sec for test to finish
			waitOneSecond();			
			log.debug("EndOf testAppendUpdateCriteria");
		}
		
		public function onInsertListCollections(rep:MongoDocumentResponse, token:*):void {
			driver.listCollections(new MongoResponder(onResponseReceivedTestListCollections));
			
			// Wait a sec for test to finish
			waitOneSecond();
		}
		
		public function onResponseReceivedTestListCollections(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestListCollections responseDoc="+rep+" token="+token);
			assertTrue(rep.isOk);
			assertTrue(rep.numberReturned > 1);
			var trouve:Boolean = false;
			for each (var colName:Object in rep.interpretedResponse) {
				log.debug("Received response collection : "+colName);
				if (colName == "testu") trouve=true;
			}
			assertTrue(trouve);
		}
		
		//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
		[Test(async, timeout=5000)]
		public function testAppendUpdateCriteria():void {
			log.debug("Calling testAppendUpdateCriteria");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertAppendUpdateCriteria));
			
			// Wait a sec for test to finish
			waitOneSecond();			
			log.debug("EndOf testAppendUpdateCriteria");
		}
		
		public function onInsertAppendUpdateCriteria(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertAppendUpdateCriteria");
			
			// update with 2 criterias
			var updateDoc:MongoDocumentUpdate = new MongoDocumentUpdate(
				MongoDocument.addKeyValuePair("pageViews",5), // selector
				MongoDocument.set("author","TheNewAuthor").set("title","TheNewTitle"));
			driver.updateDoc("testu", updateDoc, new MongoResponder(onUpdateAppendUpdateCriteria));
			
		}
		
		public function onUpdateAppendUpdateCriteria(rep:MongoDocumentResponse, token:*):void {
			// Find all docs
			// Ask for all object in collections but don't interprete them
			driver.queryDoc("testu", null, new MongoResponder(onResponseReceivedTestAppendUpdateCriteria));
			
			log.debug("EndOf onInsertAppendUpdateCriteria");
		}
		
		public function onResponseReceivedTestAppendUpdateCriteria(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestAppendUpdateCriteria responseDoc="+rep+" token="+token);
			
			assertEquals(1, rep.numberReturned);
			assertEquals("TheNewAuthor",rep.interpretedResponse[0].author);
			assertEquals("TheNewTitle",rep.interpretedResponse[0].title);
			
			log.debug("EndOf onResponseReceivedTestAppendUpdateCriteria");
		}
	}
}