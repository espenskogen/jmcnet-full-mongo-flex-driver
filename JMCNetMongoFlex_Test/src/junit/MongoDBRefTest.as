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
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.driver.MongoResponder;
	
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	
	import org.flexunit.asserts.*;
	import org.flexunit.async.Async;

	public class MongoDBRefTest extends MongoBaseFlexUnitTest
	{		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoDBRefTest);
		
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
		
		public function MongoDBRefTest() {
			setFineDebugLevel(false, false);
			super(CONNECT_TYPE_ON_SET_UP, "testu", DATABASENAME, USERNAME, PASSWORD, SERVER, PORT, JMCNetMongoDBDriver.SAFE_MODE_NORMAL, 1, 1);
			log.info("EndOf MongoDBRefTest CTOR initialization");
		}
		
		// To verify that all is allright
		[Test(async, timeout=5000)]
		override public function testFlexUnitEnv():void {
			log.debug("------ Calling testFlexUnitEnv");
			
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
		
		
		[Test(async, timeout=5000)]
		public function testDBRefOnSameCollection():void {
			log.debug("Calling testDBRefOnSameCollection");
			
			// We are connected, so write the doc composed of an ArrayCollection
			doc1.doc2Ref = MongoDocument.dbRef("testu", doc2._id);
			driver.insertDoc("testu", [doc1, doc2], new MongoResponder(onInsertDBRefOnSameCollection));
			driver.getLastError();
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedDBRefOnSameCollection));
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.debug("EndOf testDBRefOnSameCollection");
		}
		
		public function onInsertDBRefOnSameCollection(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertDBRefOnSameCollection");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		public function onResponseReceivedDBRefOnSameCollection(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedDBRefOnSameCollection responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];

			assertEquals(doc1.title, repDoc1.title);
			assertNotNull(doc1.doc2Ref);
			assertEquals("testu", repDoc1.doc2Ref.$ref);
			assertEquals(doc2._id.toString(), repDoc1.doc2Ref.$id);
			
			log.debug("EndOf onResponseReceivedDBRefOnSameCollection");
		}
	}
}