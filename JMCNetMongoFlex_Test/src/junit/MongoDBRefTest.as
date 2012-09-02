package junit
{
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import flexunit.framework.Assert;
	
	import jmcnet.libcommun.communs.helpers.HelperDate;
	import jmcnet.libcommun.flexunit.MongoBaseFlexUnitTest;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.logger.JMCNetLogger;
	import jmcnet.mongodb.documents.DBRef;
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
			setFineDebugLevel(false, false, false);
			super(CONNECT_TYPE_ON_SET_UP, "testu", DATABASENAME, USERNAME, PASSWORD, SERVER, PORT, JMCNetMongoDBDriver.SAFE_MODE_NORMAL, 1, 1);
			
			JMCNetLogger.setLogLevel(JMCNetLogger.DEBUG);
			log.info("EndOf MongoDBRefTest CTOR initialization");
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
		
		[Test]
		public function testDBRef2Document():void {
			log.info("------\nCalling testDBRefOnSameCollection");
			var doc:MongoDocument;
			var doc2:MongoDocument;
			var dbref:DBRef;
			
			var objId:ObjectID = ObjectID.createFromString("theId");
			
			// 1. Normal case
			doc = MongoDocument.addKeyValuePair("$ref", "collectionName").addKeyValuePair("$id", objId);
			assertTrue(doc.isDBRef());
			dbref = doc.toDBRef();
			assertEquals("collectionName",dbref.collectionName);
			assertEquals(objId.toString(), dbref.id.toString());
			assertNull(dbref.databaseName);
			// convert back to MongoDocument
			doc2 = dbref.toMongoDocument()
			assertEquals(doc.toString(), doc2.toString());

			// 2. invalid ref
			doc = MongoDocument.addKeyValuePair("$rf", "collectionName").addKeyValuePair("$id",objId);
			assertFalse(doc.isDBRef());
			try {
				doc.toDBRef();
				fail("We should not be able to convert an invalid DBRef doc into DBRef");
			} catch (e:Error) {
				// OK
			}
			
			
			// 3. invalid id
			doc = MongoDocument.addKeyValuePair("$ref", "collectionName").addKeyValuePair("$ide", objId);
			assertFalse(doc.isDBRef());
			
			// 4. Normal case with databaseName
			doc = MongoDocument.addKeyValuePair("$ref", "collectionName").addKeyValuePair("$id",objId).addKeyValuePair("$db","databaseName");
			assertTrue(doc.isDBRef());
			dbref = doc.toDBRef();
			assertEquals("collectionName",dbref.collectionName);
			assertEquals(objId.toString(), dbref.id.toString());
			assertEquals("databaseName", dbref.databaseName);
			// convert back to MongoDocument
			doc2 = dbref.toMongoDocument()
			assertEquals(doc.toString(), doc2.toString());
			
			// 5. invalid db
			doc = MongoDocument.addKeyValuePair("$ref", "collectionName").addKeyValuePair("$id", objId).addKeyValuePair("$dab","databaseName");
			assertFalse(doc.isDBRef());
			
			// 5. extra value
			doc = MongoDocument.addKeyValuePair("$ref", "collectionName").addKeyValuePair("$id", objId).addKeyValuePair("$db","databaseName").addKeyValuePair("other","extraValue");
			assertFalse(doc.isDBRef());
			
			log.info("EndOF testDBRefOnSameCollection");
		}
		
		
		[Test(async, timeout=5000)]
		public function testDBRefOnSameCollection():void {
			log.info("------\nCalling testDBRefOnSameCollection");
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// We are connected, so write the doc composed of an ArrayCollection
			doc1.doc2Ref = new DBRef("testu", doc2._id);
			driver.insertDoc("testu", [doc1, doc2], new MongoResponder(onInsertDBRefOnSameCollection));
			driver.getLastError();
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedDBRefOnSameCollection));
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testDBRefOnSameCollection");
		}
		
		public function onInsertDBRefOnSameCollection(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onInsertDBRefOnSameCollection");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		public function onResponseReceivedDBRefOnSameCollection(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedDBRefOnSameCollection responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			var dbRef:DBRef = repDoc1.doc2Ref as DBRef;

			assertEquals(doc1.title, repDoc1.title);
			assertNotNull(dbRef);
			
			// Fetch the DBRef
			Async.failOnEvent(this, dbRef, DBRef.EVENT_DBREF_FETCH_ERROR);
			dbRef.addEventListener(DBRef.EVENT_DBREF_FETCH_COMPLETE, onFetchOnSameCollection);
			dbRef.fetch();
			
			log.info("EndOf onResponseReceivedDBRefOnSameCollection");
		}
			
		public function onFetchOnSameCollection(event:EventMongoDB):void {
			log.info("Calling onFetchOnSameCollection event="+event);
			
			var dbref:DBRef = event.target as DBRef;
			assertEquals("testu", dbref.collectionName);
			assertEquals(doc2._id.toString(), dbref.id);
			assertNull(dbref.databaseName);
			
			assertNotNull(dbref.value);
			assertEquals(doc2.title, dbref.value.title);
			assertEquals(doc2.author, dbref.value.author);
			assertEquals(doc2.pageViews, dbref.value.pageViews);
			assertEquals(doc2.comments.length, dbref.value.comments.length);
			assertEquals(doc2.other.foo, dbref.value.other.foo);
		}
		
		[Test(async, timeout=5000)]
		public function testDBRefOnOtherCollection():void {
			log.info("------\nCalling testDBRefOnOtherCollection");
			
			// We are connected, so write the doc composed of an ArrayCollection
			doc1.doc2Ref = new DBRef("testu2", doc2._id);
			driver.dropCollection("testu2");
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertDBRefOnOtherCollection));
			driver.insertDoc("testu2", [doc2], new MongoResponder(onInsertDBRefOnOtherCollection));
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedDBRefOnOtherCollection));
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testDBRefOnOtherCollection");
		}
		
		public function onInsertDBRefOnOtherCollection(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onInsertDBRefOnOtherCollection");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		public function onResponseReceivedDBRefOnOtherCollection(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedDBRefOnOtherCollection responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			var dbRef:DBRef = repDoc1.doc2Ref as DBRef;
			
			assertEquals(doc1.title, repDoc1.title);
			assertNotNull(dbRef);
			
			// Fetch the DBRef
			Async.failOnEvent(this, dbRef, DBRef.EVENT_DBREF_FETCH_ERROR);
			dbRef.addEventListener(DBRef.EVENT_DBREF_FETCH_COMPLETE, onFetchOnOtherCollection);
			dbRef.fetch();
			
			log.info("EndOf onResponseReceivedDBRefOnOtherCollection");
		}
		
		public function onFetchOnOtherCollection(event:EventMongoDB):void {
			log.info("Calling onFetchOnOtherCollection event="+event);
			
			var dbref:DBRef = event.target as DBRef;
			assertEquals("testu2", dbref.collectionName);
			assertEquals(doc2._id.toString(), dbref.id);
			assertNull(dbref.databaseName);
			
			assertNotNull(dbref.value);
			assertEquals(doc2.title, dbref.value.title);
			assertEquals(doc2.author, dbref.value.author);
			assertEquals(doc2.pageViews, dbref.value.pageViews);
			assertEquals(doc2.comments.length, dbref.value.comments.length);
			assertEquals(doc2.other.foo, dbref.value.other.foo);
			
			// Cleanup test
			driver.dropCollection("testu2");
			
			log.info("EndOf onFetchOnOtherCollection");
		}
		
		private var driver2:JMCNetMongoDBDriver = new JMCNetMongoDBDriver();
		[Test(async, timeout=5000)]
		public function testDBRefOnOtherDatabase():void {
			log.info("------\nCalling testDBRefOnOtherDatabase");
			
			driver2.databaseName = "testDatabase2";
			driver2.hostname = "jmcsrv2";
			driver2.port = 27017;
			driver2.username = "testu";
			driver2.password = "testu";
			driver2.socketPoolMax = 1;
			driver2.socketPoolMin = 1;
			driver2.setWriteConcern(JMCNetMongoDBDriver.SAFE_MODE_NORMAL);
			
			driver2.addEventListener(JMCNetMongoDBDriver.EVT_CONNECTOK, onDriver2ConnectOK);
			driver2.connect();
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testDBRefOnOtherDatabase");
		}
		
		public function onDriver2ConnectOK(event:EventMongoDB):void {
			log.info("Calling onDriver2ConnectOK");
			
			// We are connected, so write the doc composed of an ArrayCollection
			doc1.doc2Ref = new DBRef("testu2", doc2._id, "testDatabase2");
			driver2.dropCollection("testu2");
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertDBRefOnOtherDatabase));
			driver2.insertDoc("testu2", [doc2], new MongoResponder(onInsertDBRefOnOtherDatabase));
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedDBRefOnOtherDatabase));
			
			log.info("EndOf onDriver2ConnectOK");
		}
		
		public function onInsertDBRefOnOtherDatabase(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onInsertDBRefOnOtherDatabase");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		public function onResponseReceivedDBRefOnOtherDatabase(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedDBRefOnOtherDatabase responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			var dbRef:DBRef = repDoc1.doc2Ref as DBRef;
			
			assertEquals(doc1.title, repDoc1.title);
			assertNotNull(dbRef);
			
			// Fetch the DBRef
			Async.failOnEvent(this, dbRef, DBRef.EVENT_DBREF_FETCH_ERROR);
			dbRef.addEventListener(DBRef.EVENT_DBREF_FETCH_COMPLETE, onFetchOnOtherDatabase);
			dbRef.fetch();
			
			log.info("EndOf onResponseReceivedDBRefOnOtherDatabase");
		}
		
		public function onFetchOnOtherDatabase(event:EventMongoDB):void {
			log.info("Calling onFetchOnOtherDatabase event="+event);
			
			var dbref:DBRef = event.target as DBRef;
			assertEquals("testu2", dbref.collectionName);
			assertEquals(doc2._id.toString(), dbref.id);
			assertEquals("testDatabase2", dbref.databaseName);
			
			assertNotNull(dbref.value);
			assertEquals(doc2.title, dbref.value.title);
			assertEquals(doc2.author, dbref.value.author);
			assertEquals(doc2.pageViews, dbref.value.pageViews);
			assertEquals(doc2.comments.length, dbref.value.comments.length);
			assertEquals(doc2.other.foo, dbref.value.other.foo);
			
			// Cleanup test
			driver2.dropCollection("testu2");
			driver2.disconnect();
			
			log.info("EndOf onFetchOnOtherDatabase");
		}
		
		[Test(async, timeout=5000)]
		public function testFetchDoc():void {
			log.info("------\nCalling testFetchDoc");
			
			// Don't fetch automatically DBRefs
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// Test principle : 2 docs with a dbRef
			doc1.doc2Ref = new DBRef("testu2", doc2._id);
			driver.dropCollection("testu2");
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertFetchDoc));
			driver.insertDoc("testu2", [doc2], new MongoResponder(onInsertFetchDoc));
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedFetchDoc));
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testFetchDoc");
		}
		
		public function onInsertFetchDoc(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onInsertFetchDoc");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		public function onResponseReceivedFetchDoc(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedFetchDoc responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc:MongoDocument = rep.documents[0];
			var repDoc1:Object = rep.interpretedResponse[0];
			var dbRef:DBRef = repDoc1.doc2Ref as DBRef;			
			assertEquals(doc1.title, repDoc1.title);
			assertNotNull(dbRef);
			// dbRef has not been fetched, so it's null
			assertNull(dbRef.value);
			
			// Fetch the doc
			Async.failOnEvent(this, dbRef, MongoDocument.EVENT_DOCUMENT_FETCH_ERROR);
			repDoc.addEventListener(MongoDocument.EVENT_DOCUMENT_FETCH_COMPLETE, onFetchDoc);
			repDoc.fetchDBRef(1);
			
			log.info("EndOf onResponseReceivedFetchDoc");
		}
		
		public function onFetchDoc(event:EventMongoDB):void {
			log.info("Calling onFetchDoc event="+event);
			
			var doc:MongoDocument = event.target as MongoDocument;
			var docObj:Object = doc.toObject();
			assertEquals("testu2", docObj.doc2Ref.collectionName);
			assertEquals(doc2._id.toString(), docObj.doc2Ref.id);
			assertNull(docObj.doc2Ref.databaseName);
			
			assertNotNull(docObj.doc2Ref.value);
			assertEquals(doc2.title, docObj.doc2Ref.value.title);
			assertEquals(doc2.author, docObj.doc2Ref.value.author);
			assertEquals(doc2.pageViews, docObj.doc2Ref.value.pageViews);
			assertEquals(doc2.comments.length, docObj.doc2Ref.value.comments.length);
			assertEquals(doc2.other.foo, docObj.doc2Ref.value.other.foo);
			
			// Cleanup test
			driver.dropCollection("testu2");
			
			log.info("EndOf onFetchDoc");
		}
		
		[Test(async, timeout=5000)]
		public function testFetchDocComplex():void {
			log.info("------\nCalling testFetchDocComplex");
			
			// Fetch automatically DBRefs until depth 3
			JMCNetMongoDBDriver.maxDBRefDepth = 3;
			
			// Test principle : 3 docs. doc1.doc2ref=DBRef on doc2, doc2.doc3ref = DBRef on doc3, doc3.docRefs[ DBRef on doc1, and doc2], doc3.doc1ref = DBRef on doc1 (circular reference) 
			doc1.doc2Ref = new DBRef("testu2", doc2._id);
			doc2.doc3Ref = new DBRef("testu2", doc3._id);
			doc3.docRefs = new Array(new DBRef("testu", doc1._id), new DBRef("testu2", doc2._id));
			doc3.doc1Ref = new DBRef("testu", doc1._id);
			
			driver.dropCollection("testu2");
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertFetchDocComplex));
			driver.insertDoc("testu2", [doc2, doc3], new MongoResponder(onInsertFetchDocComplex));
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedFetchDocComplex));
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testFetchDocComplex");
		}
		
		public function onInsertFetchDocComplex(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onInsertFetchDocComplex");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		public function onResponseReceivedFetchDocComplex(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedFetchDocComplex responseDoc="+rep+" token="+token);
			
			assertTrue(rep.isOk);
			assertEquals(1, rep.interpretedResponse.length);
			
			var repDoc1:Object = rep.interpretedResponse[0];
			assertEquals(doc1.title, repDoc1.title);
			
			// Level 1
			assertNotNull(repDoc1.doc2Ref);
			// dbRef has been fetched, so it's not null
			assertNotNull(repDoc1.doc2Ref.value);
			assertEquals(doc2.title, repDoc1.doc2Ref.value.title);
			
			// Level2
			var dbref3:DBRef = repDoc1.doc2Ref.value.doc3Ref;
			assertNotNull(dbref3);
			assertNotNull(dbref3.value);
			assertEquals(doc3.title, dbref3.value.title);
			
			// Level3
			assertNotNull(dbref3.value.doc1Ref);
			assertNotNull(dbref3.value.doc1Ref.value);
			assertEquals(doc1.title, dbref3.value.doc1Ref.value.title);
			
			assertTrue(dbref3.value.docRefs is ArrayCollection);
			assertEquals(2, dbref3.value.docRefs.length);
			assertNotNull(dbref3.value.docRefs[0]);
			assertNotNull(dbref3.value.docRefs[1]);
			assertEquals(doc1.title, dbref3.value.docRefs[0].value.title);
			assertEquals(doc2.title, dbref3.value.docRefs[1].value.title);
			
			// Level4 => null
			assertNull(dbref3.value.doc1Ref.value.doc2ref);
			assertNull(dbref3.value.docRefs[1].value.doc3ref);
			assertNull(dbref3.value.docRefs[0].value.doc2ref);
			
			log.info("EndOf onResponseReceivedFetchDocComplex");
		}
		
		[Test(async, timeout=5000)]
		public function testFetchDocError():void {
			log.info("------\nCalling testFetchDocError");
			
			// Fetch automatically DBRefs until depth 3
			JMCNetMongoDBDriver.maxDBRefDepth = 3;
			
			// Test principle : 3 docs. doc1.doc2ref=DBRef on doc2, doc2.doc3ref = DBRef on doc3, doc3.docRefs[ DBRef on doc1, and doc2], doc3.doc1ref = DBRef on doc1 (circular reference) 
			doc1.doc2Ref = new DBRef("testu2", doc2._id);
			doc2.doc3Ref = new DBRef("testu2", doc3._id);
			doc3.doc1Ref = new DBRef("testu", ObjectID.createFromString("doesn't exists"));
			
			driver.dropCollection("testu2");
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertFetchDocError));
			driver.insertDoc("testu2", [doc2, doc3], new MongoResponder(onInsertFetchDocError));
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedFetchDocError));
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testFetchDocError");
		}
		
		public function onInsertFetchDocError(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onInsertFetchDocError");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		public function onResponseReceivedFetchDocError(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedFetchDocError responseDoc="+rep+" token="+token);
			
			assertFalse(rep.isOk);
			
			log.info("EndOf onResponseReceivedFetchDocError");
		}
		
		[Test(async, timeout=5000)]
		public function testFetchDocErrorManually():void {
			log.info("------\nCalling testFetchDocErrorManually");
			
			// Don't fetch automatically
			JMCNetMongoDBDriver.maxDBRefDepth = 0;
			
			// Test principle : 3 docs. doc1.doc2ref=DBRef on doc2, doc2.doc3ref = DBRef on doc3, doc3.docRefs[ DBRef on doc1, and doc2], doc3.doc1ref = DBRef on doc1 (circular reference) 
			doc1.doc2Ref = new DBRef("testu2", doc2._id);
			doc2.doc3Ref = new DBRef("testu2", doc3._id);
			doc3.doc1Ref = new DBRef("testu", ObjectID.createFromString("doesn't exists"));
			
			driver.dropCollection("testu2");
			driver.insertDoc("testu", [doc1], new MongoResponder(onInsertFetchDocErrorManually));
			driver.insertDoc("testu2", [doc2, doc3], new MongoResponder(onInsertFetchDocErrorManually));
			driver.queryDoc(
				"testu",
				new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
				new MongoResponder(onResponseReceivedFetchDocErrorManuallyOK, onResponseReceivedFetchDocErrorManuallyError));
			
			// Wait a sec for test to finish
			waitOneSecond();
			log.info("EndOf testFetchDocErrorManually");
		}
		
		public function onInsertFetchDocErrorManually(response:MongoDocumentResponse, token:*):void {
			log.info("Calling onInsertFetchDocErrorManually");
			// must not be called because, SAFE_MODE is normal and insertDoc don't have any result
			fail("Callback on insertDoc should not be called because safeMode is NORMAL.");
		}
		
		
		public function onResponseReceivedFetchDocErrorManuallyOK(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedFetchDocErrorManuallyOK responseDoc="+rep+" token="+token);
			// Fetch the doc
			var repDoc:MongoDocument = rep.documents[0];
			Async.failOnEvent(this, repDoc, MongoDocument.EVENT_DOCUMENT_FETCH_COMPLETE);
			repDoc.addEventListener(MongoDocument.EVENT_DOCUMENT_FETCH_ERROR, onFetchDocError);
			repDoc.fetchDBRef(3);
		}
		
		// This should not be called because fetching is not automatic
		public function onResponseReceivedFetchDocErrorManuallyError(rep:MongoDocumentResponse, token:*):void {
			log.info("Calling onResponseReceivedFetchDocErrorManuallyError responseDoc="+rep+" token="+token);
			
			fail("This method should not be called because manual fetching");
			
			log.info("EndOf onResponseReceivedFetchDocErrorManually");
		}
		
		// This should not be called because fetching is not automatic
		public function onFetchDocError(event:EventMongoDB):void {
			log.info("Calling onFetchDocError event="+event.toString());
			
			// Normal to be here ...
			assertTrue(true);
			
			log.info("EndOf onFetchDocError");
		}	
	}
}