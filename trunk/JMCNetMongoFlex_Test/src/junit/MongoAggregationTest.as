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

	public class MongoAggregationTest extends MongoBaseFlexUnitTest
	{		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoAggregationTest);
		
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
		
		public function MongoAggregationTest() {
			setFineDebugLevel(false, false, false);
			super(CONNECT_TYPE_ON_SET_UP, "testu", DATABASENAME, USERNAME, PASSWORD, SERVER, PORT, JMCNetMongoDBDriver.SAFE_MODE_SAFE, 2, 2);
			log.info("EndOf MongoAggregationTest CTOR initialization");
		}
		
		// To verify that all is allright
		[Test(async, timeout=5000)]
		override public function testFlexUnitEnv():void {
			log.debug("------ Calling testFlexUnitEnv");
			super.testFlexUnitEnv();
			
			// Wait a sec for test to finish
			waitOneSecond();
//			var t:Timer = new Timer(1000, 1);
//			log.debug("starting timer to wait for test to finish");
//			t.start();
//			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
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
		
		[Test(async, timeout=5000)]
		public function testProject():void {
			log.debug("Calling testProject");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestProject));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testProject");
		}
		
		public function onInsertTestProject(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestProject");
			// Find the doc
//			var query:MongoDocumentQuery=new MongoDocumentQuery();
			// Ask for all object in collections
//			driver.queryDoc("testu", query, new MongoResponder(onResponseReceivedTestProject));
			
			// Build a $project aggregation
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.addProjectOperator(
					new MongoDocument().addKeyValuePair("title",1).
										addKeyValuePair("author",1).
										addKeyValuePair("_id",0).
										addKeyValuePair("posted",1).
										addKeyValuePair("doctoredPageViews", MongoDocument.add("$pageViews",10)).
										addKeyValuePair("comp",MongoDocument.cmp(6,"$pageViews")).
										addKeyValuePair("subtitle", MongoDocument.substr("$title",1,6)).
										addKeyValuePair("upperAuthor", MongoDocument.toUpper("$author")).
										addKeyValuePair("dayOfMonth", MongoDocument.dayOfMonth("$posted")).
										addKeyValuePair("hour", MongoDocument.hour("$posted")).
										addKeyValuePair("month", MongoDocument.month("$posted")).
										addKeyValuePair("second", MongoDocument.second("$posted"))
				);
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestProject));
			log.debug("EndOf onInsertTestProject");
		}
		
		public function onResponseReceivedTestProject(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestProject responseDoc="+rep+" token="+token);
			
			assertEquals(1, rep.documents.length);
			var aggregResult:Object = (rep.documents[0] as MongoDocument).toObject();
			log.debug("Received aggregResult : "+ObjectUtil.toString(aggregResult));
			
			assertTrue(aggregResult.ok);
			assertNotNull(aggregResult.result);
			assertEquals(3, aggregResult.result.length);
			
			assertTrue(rep.isOk);
			assertEquals(3, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			var repDoc2:Object = rep.interpretedResponse[1];
			var repDoc3:Object = rep.interpretedResponse[2];
			log.debug("Received doc[0] : "+ObjectUtil.toString(repDoc1));
			log.debug("Received doc[1] : "+ObjectUtil.toString(repDoc2));
			log.debug("Received doc[2] : "+ObjectUtil.toString(repDoc3));
			
			assertTrue(repDoc1.hasOwnProperty("title"));
			assertEquals(doc1.title, repDoc1.title);
			assertTrue(repDoc1.hasOwnProperty("author"));
			assertEquals(doc1.author, repDoc1.author);
			assertTrue(repDoc1.hasOwnProperty("posted"));
			assertTrue(repDoc1.hasOwnProperty("doctoredPageViews"));
			assertEquals(15, repDoc1.doctoredPageViews);
			assertTrue(repDoc1.hasOwnProperty("comp"));
			assertTrue(repDoc1.comp > 0);
			assertTrue(repDoc1.hasOwnProperty("subtitle"));
			assertEquals("his is", repDoc1.subtitle);
			assertTrue(repDoc1.hasOwnProperty("upperAuthor"));
			assertEquals("BOB", repDoc1.upperAuthor);
			assertEquals(d1.time, repDoc1.posted.time);
			assertEquals(d1.dateUTC, repDoc1.dayOfMonth);
			assertEquals(d1.monthUTC+1, repDoc1.month);
			assertEquals(d1.hoursUTC, repDoc1.hour);
			assertEquals(d1.secondsUTC, repDoc1.second);
			
			assertTrue(repDoc2.hasOwnProperty("title"));
			assertEquals(doc2.title, repDoc2.title);
			assertTrue(repDoc2.hasOwnProperty("author"));
			assertEquals(doc2.author, repDoc2.author);
			assertTrue(repDoc2.hasOwnProperty("posted"));
			assertFalse(repDoc2.hasOwnProperty("pageViews"));
			assertTrue(repDoc2.hasOwnProperty("doctoredPageViews"));
			assertEquals(16, repDoc2.doctoredPageViews);
			assertTrue(repDoc2.hasOwnProperty("comp"));
			assertTrue(repDoc2.comp == 0);
			assertTrue(repDoc2.hasOwnProperty("subtitle"));
			assertEquals("his is", repDoc2.subtitle);
			assertTrue(repDoc2.hasOwnProperty("upperAuthor"));
			assertEquals("TONY", repDoc2.upperAuthor);
			assertEquals(d2.time, repDoc2.posted.time);
			assertEquals(d2.dateUTC, repDoc2.dayOfMonth);
			assertEquals(d2.monthUTC+1, repDoc2.month);
			assertEquals(d2.hoursUTC, repDoc2.hour);
			assertEquals(d2.secondsUTC, repDoc2.second);
			
			assertTrue(repDoc3.hasOwnProperty("title"));
			assertEquals(doc3.title, repDoc3.title);
			assertTrue(repDoc3.hasOwnProperty("author"));
			assertEquals(doc3.author, repDoc3.author);
			assertTrue(repDoc1.hasOwnProperty("posted"));
			assertFalse(repDoc3.hasOwnProperty("tags"));
			assertTrue(repDoc3.hasOwnProperty("doctoredPageViews"));
			assertEquals(17, repDoc3.doctoredPageViews);
			assertTrue(repDoc3.hasOwnProperty("comp"));
			assertTrue(repDoc3.comp < 0);
			assertTrue(repDoc3.hasOwnProperty("subtitle"));
			assertEquals("his is", repDoc3.subtitle);
			assertTrue(repDoc3.hasOwnProperty("upperAuthor"));
			assertEquals("BOB", repDoc3.upperAuthor);
			assertEquals(d3.time, repDoc3.posted.time);
			assertEquals(d3.dateUTC, repDoc3.dayOfMonth);
			assertEquals(d3.monthUTC+1, repDoc3.month);
			assertEquals(d3.hoursUTC, repDoc3.hour);
			assertEquals(d3.secondsUTC, repDoc3.second);
			
			log.debug("EndOf onResponseReceivedTestProject");
		}
		
		[Test(async, timeout=5000)]
		public function testMatch():void {
			log.debug("Calling testMatch");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestMatch));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testMatch");
		}
		
		public function onInsertTestMatch(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestMatch");
			// Build a $match aggregation (select author, title from testu where pageViews-6 = 1)
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.addProjectOperator(
					new MongoDocument().addKeyValuePair("title",1).
					addKeyValuePair("author",1).
					addKeyValuePair("_id",0).
					addKeyValuePair("comp",MongoDocument.cmp("$pageViews", 6))).
				addMatchOperator(new MongoDocument().addKeyValuePair("comp", 1));
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestMatch));
			log.debug("EndOf onInsertTestMatch");
		}
		
		public function onResponseReceivedTestMatch(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestMatch responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			
			log.debug("Received doc[0] : "+ObjectUtil.toString(repDoc1));
			
			assertTrue(repDoc1.hasOwnProperty("title"));
			assertEquals(doc3.title, repDoc1.title);
			assertTrue(repDoc1.hasOwnProperty("author"));
			assertEquals(doc3.author, repDoc1.author);
			assertFalse(repDoc1.hasOwnProperty("posted"));
			assertFalse(repDoc1.hasOwnProperty("doctoredPageViews"));
			assertTrue(repDoc1.hasOwnProperty("comp"));
			assertTrue(repDoc1.comp > 0);			
			
			log.debug("EndOf onResponseReceivedTestMatch");
		}
		
		[Test(async, timeout=5000)]
		public function testLimitSkip():void {
			log.debug("Calling testLimitSkip");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestLimitSkip));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testLimitSkip");
		}
		
		public function onInsertTestLimitSkip(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestLimitSkip");
			// Find the doc
			//			var query:MongoDocumentQuery=new MongoDocumentQuery();
			// Ask for all object in collections
			//			driver.queryDoc("testu", query, new MongoResponder(onResponseReceivedTestLimit));
			
			// Build a $project aggregation
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.addProjectOperator(
					new MongoDocument().addKeyValuePair("title",1).
					addKeyValuePair("author",1)).
				addSkipOperator(1).
				addLimitOperator(1);
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestLimitSkip));
			log.debug("EndOf onInsertTestLimitSkip");
		}
		
		public function onResponseReceivedTestLimitSkip(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestLimitSkip responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			
			log.debug("Received doc[0] : "+ObjectUtil.toString(repDoc1));
			
			assertTrue(repDoc1.hasOwnProperty("title"));
			assertEquals(doc2.title, repDoc1.title);
			assertTrue(repDoc1.hasOwnProperty("author"));
			assertEquals(doc2.author, repDoc1.author);
			
			log.debug("EndOf onResponseReceivedTestLimitSkip");
		}
		
		[Test(async, timeout=5000)]
		public function testUnwind():void {
			log.debug("Calling testUnwind");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestUnwind));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testUnwind");
		}
		
		public function onInsertTestUnwind(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestUnwind");
			
			// Build a $unwind aggregation
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.
				addUnwindOperator("tags")
				.addProjectOperator(
					new MongoDocument().addKeyValuePair("title",1).
					addKeyValuePair("author",1).
					addKeyValuePair("tags",1))
			;
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestUnwind));
			log.debug("EndOf onInsertTestUnwind");
		}
		
		public function onResponseReceivedTestUnwind(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestUnwind responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(8, rep.interpretedResponse.length);
			
			log.debug("EndOf onResponseReceivedTestUnwind");
		}
		
		[Test(async, timeout=5000)]
		public function testGroup():void {
			log.debug("Calling testGroup");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestGroup));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testGroup");
		}
		
		public function onInsertTestGroup(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestGroup");
			
			// Build a $unwind aggregation
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.
					addGroupOperator(new MongoDocument().
						addKeyValuePair("_id", "$author").
						addKeyValuePair("docsPerAuthor", MongoDocument.sum(1)).
						addKeyValuePair("viewPerAuthor", MongoDocument.sum("$pageViews")).
						addKeyValuePair("maxPageViews", MongoDocument.max("$pageViews")).
						addKeyValuePair("minPageViews", MongoDocument.min("$pageViews")).
						addKeyValuePair("avgPageViews", MongoDocument.avg("$pageViews")).
						addKeyValuePair("setOther", MongoDocument.addToSet("$other.foo")).
						addKeyValuePair("pushOther", MongoDocument.push("$other.foo"))
					)
				;
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestGroup));
			log.debug("EndOf onInsertTestGroup");
		}
		
		public function onResponseReceivedTestGroup(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestGroup responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(2, rep.interpretedResponse.length);
			
			var repDoc1:Object; // result for bob
			var repDoc2:Object; // result for tony
			if (rep.interpretedResponse[0]._id == "bob") {
				repDoc1 = rep.interpretedResponse[0];
				repDoc2 = rep.interpretedResponse[1];
			}
			else  {
				repDoc2 = rep.interpretedResponse[0];
				repDoc1 = rep.interpretedResponse[1];
			}
			
			assertEquals(2, repDoc1.docsPerAuthor);
			assertEquals(12, repDoc1.viewPerAuthor);
			assertEquals(7, repDoc1.maxPageViews);
			assertEquals(5, repDoc1.minPageViews);
			assertEquals(6, repDoc1.avgPageViews);
			assertEquals(1, repDoc1.setOther.length);
			assertEquals(10, repDoc1.setOther[0]);
			assertEquals(2, repDoc1.pushOther.length);
			assertEquals(10, repDoc1.pushOther[0]);
			assertEquals(10, repDoc1.pushOther[1]);
				
			assertEquals(1, repDoc2.docsPerAuthor);
			assertEquals(6, repDoc2.viewPerAuthor);
			assertEquals(6, repDoc2.maxPageViews);
			assertEquals(6, repDoc2.minPageViews)
			assertEquals(6, repDoc2.avgPageViews)
			assertEquals(1, repDoc2.setOther.length)
			assertEquals(5, repDoc2.setOther[0]);
			assertEquals(1, repDoc2.pushOther.length)
			assertEquals(5, repDoc2.pushOther[0]);
			
			log.debug("EndOf onResponseReceivedTestGroup");
		}
		
		[Test(async, timeout=5000)]
		public function testSort():void {
			log.debug("Calling testSort");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestSort));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testSort");
		}
		
		public function onInsertTestSort(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestSort");
			
			// Build a $sort aggregation
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.
				addSortOperator(new MongoDocument().
					addKeyValuePair("posted", 1).
					addKeyValuePair("other.foo", -1)
				)
				;
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestSort));
			log.debug("EndOf onInsertTestSort");
		}
		
		public function onResponseReceivedTestSort(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestSort responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(3, rep.interpretedResponse.length);
			
			assertEquals("this is my third title", rep.interpretedResponse[0].title);
			assertEquals("this is my second title", rep.interpretedResponse[1].title);
			assertEquals("this is my first title", rep.interpretedResponse[2].title);

			log.debug("EndOf onResponseReceivedTestSort");
		}
		
		[Test(async, timeout=5000)]
		public function testCondition():void {
			log.debug("Calling testCondition");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestCondition));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testCondition");
		}
		
		public function onInsertTestCondition(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestCondition");
			
			// Build a $cond aggregation
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.addProjectOperator(new MongoDocument().
					addKeyValuePair("title",1).
					addKeyValuePair("sixPagesView",MongoDocument.cond(MongoDocument.eq("$pageViews", 6), true, false)).
					addKeyValuePair("notNullcomments", MongoDocument.ifNull("$comments", []))
					).addSortOperator(new MongoDocument("posted",-1));
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestCondition));
			log.debug("EndOf onInsertTestCondition");
		}
		
		public function onResponseReceivedTestCondition(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestCondition responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(3, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			var repDoc2:Object = rep.interpretedResponse[1];
			var repDoc3:Object = rep.interpretedResponse[2];
			log.debug("Received doc[0] : "+ObjectUtil.toString(repDoc1));
			log.debug("Received doc[1] : "+ObjectUtil.toString(repDoc2));
			log.debug("Received doc[2] : "+ObjectUtil.toString(repDoc3));
			
			assertEquals(doc1.title, repDoc1.title);
			assertFalse(repDoc1.sixPagesView);
			assertEquals(2, repDoc1.notNullcomments.length);
			assertEquals(doc2.title, repDoc2.title);
			assertTrue(repDoc2.sixPagesView);
			assertEquals(2, repDoc2.notNullcomments.length);
			assertEquals(doc3.title, repDoc3.title);
			assertFalse(repDoc3.sixPagesView);
			assertTrue(repDoc3.hasOwnProperty("notNullcomments"));
			assertEquals(0, repDoc3.notNullcomments.length);
			
			log.debug("EndOf onResponseReceivedTestCondition");
		}
		
		[Test(async, timeout=5000)]
		public function testErrorAggregation():void {
			log.debug("Calling testErrorAggregation");
			
			// We are connected, so write the doc composed of an ArrayCollection
			driver.insertDoc("testu", [doc1, doc2, doc3], new MongoResponder(onInsertTestErrorAggregation));
			
			// Wait a sec for test to finish
			var t:Timer = new Timer(1000, 1);
			log.debug("starting timer to wait for insert");
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, voidFunction, 2000);
			
			log.debug("EndOf testErrorAggregation");
		}
		
		public function onInsertTestErrorAggregation(response:MongoDocumentResponse, token:*):void {
			log.debug("Calling onInsertTestErrorAggregation");
			
			// Build a $cond aggregation
			var pipeline:MongoAggregationPipeline =
				MongoAggregationPipeline.addProjectOperator(new MongoDocument().
					// cannot have a $
					addKeyValuePair("$title",1)
				).addSortOperator(new MongoDocument("posted",-1));
			driver.aggregate("testu", pipeline, new MongoResponder(onResponseReceivedTestErrorAggregation, onErrorReceivedTestErrorAggregation));
			log.debug("EndOf onInsertTestCondition");
		}
		
		public function onResponseReceivedTestErrorAggregation(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onResponseReceivedTestErrorAggregation responseDoc="+rep+" token="+token);
		
			// We should be there because there is an error...
			fail("We should not do $project aggregation with error");
		}
		
		public function onErrorReceivedTestErrorAggregation(rep:MongoDocumentResponse, token:*):void {
			log.debug("Calling onErrorReceivedTestErrorAggregation responseDoc="+rep+" token="+token);
			
			assertFalse(rep.isOk);
			assertNotNull(rep.errorMsg);
			log.debug("onErrorReceivedTestErrorAggregation : errorMsg="+rep.errorMsg);
			assertNull(rep.interpretedResponse);
			
			// Verify the raw response
			assertNotNull(rep.documents);
			assertEquals(1, rep.documents.length);
			
			log.debug("EndOf onErrorReceivedTestErrorAggregation");
		}
	}
}