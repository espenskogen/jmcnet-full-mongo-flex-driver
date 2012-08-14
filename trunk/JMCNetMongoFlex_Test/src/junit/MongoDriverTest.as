package junit
{
	import flash.events.TimerEvent;
	import flash.utils.ByteArray;
	import flash.utils.Timer;
	import flash.utils.getQualifiedClassName;
	
	import flexunit.framework.Assert;
	
	import jmcnet.libcommun.communs.helpers.HelperClass;
	import jmcnet.libcommun.communs.helpers.HelperDate;
	import jmcnet.libcommun.communs.helpers.HelperString;
	import jmcnet.libcommun.communs.structures.HashTable;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.libcommun.logger.JMCNetLogger;
	import jmcnet.mongodb.bson.BSONDecoder;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.bson.HelperByteArray;
	import jmcnet.mongodb.documents.MongoDocument;
	import jmcnet.mongodb.documents.MongoDocumentQuery;
	import jmcnet.mongodb.documents.MongoDocumentResponse;
	import jmcnet.mongodb.documents.MongoDocumentUpdate;
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;
	import jmcnet.mongodb.messages.MongoMsgHeader;
	import jmcnet.mongodb.messages.MongoMsgInsert;
	import jmcnet.mongodb.messages.MongoMsgQuery;
	import jmcnet.mongodb.messages.MongoMsgUpdate;
	
	import org.flexunit.asserts.fail;
	import org.flexunit.async.Async;
	
	public class MongoDriverTest
	{		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MongoDriverTest));
		
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

		
		[Before]
		public function setUp():void {
			JMCNetLogger.setLogEnabled(true, false);
			JMCNetLogger.setLogLevel(JMCNetLogger.DEBUG);
		}
		
		[After]
		public function tearDown():void
		{
			if (driver.isConnecte()) {
				// clean up -> delete object
				driver.dropCollection("testu");
				driver.disconnect();
			}
		}
		
		[BeforeClass]
		public static function setUpBeforeClass():void
		{
		}
		
		[AfterClass]
		public static function tearDownAfterClass():void {
		}
		
		/**
		 * Test with an object
		 */
		[Test]
		public function testBSONEncoderObject():void
		{
			var testVo:TestVO = new TestVO("une chaîne",12,123.456, true);
			var result:ByteArray = BSONEncoder.encodeObjectToBSON(testVo);
			
			log.debug("result object : "+HelperByteArray.byteArrayToString(result));
			
			Assert.assertEquals(
				"0x90 0x0 0x0 0x0 0x4 0x61 0x74 0x74 0x72 0x41 0x72 0x72 0x61 0x79 0x0 0x33 0x0 0x0 0x0 0x2 0x30 0x0 0x11 0x0 0x0 0x0 0x61 0x72 0x72 0x61 0x79 0x53 0x74 0x72 0x69 0x6e 0x67 0x56 0x61 0x6c 0x75 0x65 0x0 0x10 0x31 0x0 0xe 0x0 0x0 0x0 0x1 0x32 0x0 0x2 0x2b 0x87 0x16 0xd9 0x9a 0x75 0x40 0x8 0x33 0x0 0x0 0x0 0x8 0x61 0x74 0x74 0x72 0x42 0x6f 0x6f 0x6c 0x65 0x61 0x6e 0x0 0x1 0x10 0x61 0x74 0x74 0x72 0x49 0x6e 0x74 0x33 0x32 0x0 0xc 0x0 0x0 0x0 0x1 0x61 0x74 0x74 0x72 0x4e 0x75 0x6d 0x62 0x65 0x72 0x0 0x77 0xbe 0x9f 0x1a 0x2f 0xdd 0x5e 0x40 0x2 0x61 0x74 0x74 0x72 0x53 0x74 0x72 0x69 0x6e 0x67 0x0 0xc 0x0 0x0 0x0 0x75 0x6e 0x65 0x20 0x63 0x68 0x61 0xc3 0xae 0x6e 0x65 0x0 0x0",
				HelperByteArray.byteArrayToString(result));
		}
		
		[Test]
		public function testBSONEncoderSimpleObject():void
		{
			var testVo:Object = new Object();
			testVo.attr1 = 1;
			var result:ByteArray = BSONEncoder.encodeObjectToBSON(testVo);
			
			log.debug("result object : "+HelperByteArray.byteArrayToString(result));
			
			Assert.assertEquals(
				"0x10 0x0 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x31 0x0 0x1 0x0 0x0 0x0 0x0",
				HelperByteArray.byteArrayToString(result));
			
			// Decoding
			result.position=0;
			var decoStr:MongoDocument = BSONDecoder.decodeBSONToMongoDocument(result);
			Assert.assertNotNull(decoStr.getValue("attr1"));
			Assert.assertEquals(1, decoStr.getValue("attr1"));
			
			// String decoding
			var expectedResult:String=
				"{\n"+
				"    attr1 : 1\n"+
				"}";
			Assert.assertEquals(expectedResult, HelperByteArray.bsonDocumentToReadableString(result));
		}
		
		/**
		 * Test with String
		 */
		[Test]
		public function testBSONEncoderString():void
		{
			var result:ByteArray = BSONEncoder.encodeObjectToBSON("testString");
			log.debug("result string : "+HelperByteArray.byteArrayToString(result));
			Assert.assertEquals("0x16 0x0 0x0 0x0 0x2 0x0 0xb 0x0 0x0 0x0 0x74 0x65 0x73 0x74 0x53 0x74 0x72 0x69 0x6e 0x67 0x0 0x0",
				HelperByteArray.byteArrayToString(result));
		}
		
		/**
		 * Test with Number
		 */
		[Test]
		public function testBSONEncoderNumber():void
		{
			var n:Number=123.45;
			var result:ByteArray = BSONEncoder.encodeObjectToBSON(n);
			log.debug("result number : "+HelperByteArray.byteArrayToString(result));
			Assert.assertEquals("0xf 0x0 0x0 0x0 0x1 0x0 0xcd 0xcc 0xcc 0xcc 0xcc 0xdc 0x5e 0x40 0x0", HelperByteArray.byteArrayToString(result));
		}
		
		/**
		 * Test with int
		 */
		[Test]
		public function testBSONEncoderInt():void
		{
			var n:int=65536;
			var result:ByteArray = BSONEncoder.encodeObjectToBSON(n);
			log.debug("result int : "+HelperByteArray.byteArrayToString(result));
			Assert.assertEquals("0xb 0x0 0x0 0x0 0x10 0x0 0x0 0x0 0x1 0x0 0x0", HelperByteArray.byteArrayToString(result));
		}
		
		/**
		 * Test with Date
		 */
		[Test]
		public function testBSONEncoderDate():void
		{
			var n:Date=new Date(2012,05,08,15,18,38,900);
			var result:ByteArray = BSONEncoder.encodeObjectToBSON(n);
			log.debug("result date : "+HelperByteArray.byteArrayToString(result));
			Assert.assertEquals("0xf 0x0 0x0 0x0 0x9 0x0 0x37 0x1 0x0 0x0 0x34 0x23 0x3f 0xcc 0x0", HelperByteArray.byteArrayToString(result));
		}
		
		/**
		 * Test with Boolean
		 */
		[Test]
		public function testBSONEncoderBoolean():void
		{
			var n:Boolean=true;
			var result:ByteArray = BSONEncoder.encodeObjectToBSON(n);
			log.debug("result bool true : "+HelperByteArray.byteArrayToString(result));
			Assert.assertEquals("0x8 0x0 0x0 0x0 0x8 0x0 0x1 0x0", HelperByteArray.byteArrayToString(result));
			
			n=false;
			result = BSONEncoder.encodeObjectToBSON(n);
			log.debug("result bool false : "+HelperByteArray.byteArrayToString(result));
			Assert.assertEquals("0x8 0x0 0x0 0x0 0x8 0x0 0x0 0x0", HelperByteArray.byteArrayToString(result));
		}
		
		/**
		 * Test msgHeader
		 */
		[Test]
		public function testMongoMsgHeader():void {
			// Cas nominal
			var h:MongoMsgHeader = new MongoMsgHeader();
			h.opCode = MongoMsgHeader.OP_INSERT;
			h.messageLength = 18;
			h.requestID = 2;
			var ba:ByteArray = h.toBSON();
			Assert.assertEquals(h.messageLength, 18);
			Assert.assertEquals(h.requestID, 2); // OK if all tests are run
			Assert.assertEquals(h.responseTo, 0);
			Assert.assertEquals(h.opCode, MongoMsgHeader.OP_INSERT);
			Assert.assertEquals("0x12 0x0 0x0 0x0 0x2 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0xd2 0x7 0x0 0x0", HelperByteArray.byteArrayToString(ba));
			
			// Cas nominal 2
			h = new MongoMsgHeader(MongoMsgHeader.OP_DELETE);
			h.requestID = 3;
			ba = h.toBSON();
			Assert.assertEquals(h.messageLength, 0);
			Assert.assertEquals(h.requestID, 3);
			Assert.assertEquals(h.responseTo, 0);
			Assert.assertEquals(h.opCode, MongoMsgHeader.OP_DELETE);
			Assert.assertEquals("0x0 0x0 0x0 0x0 0x3 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0xd6 0x7 0x0 0x0", HelperByteArray.byteArrayToString(ba));
		}
		
		/**
		 * Test msgInsert
		 */
		[Test]
		public function testMongoMsgInsert():void {
			// Cas nominal
			var h:MongoMsgInsert = new MongoMsgInsert("dbName", "collectionName", true);
			h.requestID = 123;
			// try to convert without document
			try {
				h.toBSON();
				Assert.fail("We should be able to Insert without document");
			} catch (e:ExceptionJMCNetMongoDB) {
				// OK
			}
			
			// Add one doc without _id
			h.addDocument(new TestVO("a string", 12, 123, false));
			
			try {
				
				var ba:ByteArray = h.toBSON();
				// OK
			} catch (e:ExceptionJMCNetMongoDB) {
				Assert.fail("We should be able to Insert with a document");
			}
			Assert.assertEquals("0xb3 0x0 0x0 0x0 0x7b 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0xd2 0x7 0x0 0x0 0x1 0x0 0x0 0x0 0x64 0x62 0x4e 0x61 0x6d 0x65 0x2e 0x63 0x6f 0x6c 0x6c 0x65 0x63 0x74 0x69 0x6f 0x6e 0x4e 0x61 0x6d 0x65 0x0 0x89 0x0 0x0 0x0 0x4 0x61 0x74 0x74 0x72 0x41 0x72 0x72 0x61 0x79 0x0 0x33 0x0 0x0 0x0 0x2 0x30 0x0 0x11 0x0 0x0 0x0 0x61 0x72 0x72 0x61 0x79 0x53 0x74 0x72 0x69 0x6e 0x67 0x56 0x61 0x6c 0x75 0x65 0x0 0x10 0x31 0x0 0xe 0x0 0x0 0x0 0x1 0x32 0x0 0x2 0x2b 0x87 0x16 0xd9 0x9a 0x75 0x40 0x8 0x33 0x0 0x0 0x0 0x8 0x61 0x74 0x74 0x72 0x42 0x6f 0x6f 0x6c 0x65 0x61 0x6e 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x49 0x6e 0x74 0x33 0x32 0x0 0xc 0x0 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x4e 0x75 0x6d 0x62 0x65 0x72 0x0 0x7b 0x0 0x0 0x0 0x2 0x61 0x74 0x74 0x72 0x53 0x74 0x72 0x69 0x6e 0x67 0x0 0x9 0x0 0x0 0x0 0x61 0x20 0x73 0x74 0x72 0x69 0x6e 0x67 0x0 0x0",
				HelperByteArray.byteArrayToString(ba));
			                     
			
			// With 2 docs
			h.addDocument("just a string");
			try {
				ba= h.toBSON();
				// OK
			} catch (e:ExceptionJMCNetMongoDB) {
				Assert.fail("We should be able to Insert without document");
			}
			Assert.assertEquals(
				"0xcc 0x0 0x0 0x0 0x7b 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0xd2 0x7 0x0 0x0 0x1 0x0 0x0 0x0 0x64 0x62 0x4e 0x61 0x6d 0x65 0x2e 0x63 0x6f 0x6c 0x6c 0x65 0x63 0x74 0x69 0x6f 0x6e 0x4e 0x61 0x6d 0x65 0x0 0x89 0x0 0x0 0x0 0x4 0x61 0x74 0x74 0x72 0x41 0x72 0x72 0x61 0x79 0x0 0x33 0x0 0x0 0x0 0x2 0x30 0x0 0x11 0x0 0x0 0x0 0x61 0x72 0x72 0x61 0x79 0x53 0x74 0x72 0x69 0x6e 0x67 0x56 0x61 0x6c 0x75 0x65 0x0 0x10 0x31 0x0 0xe 0x0 0x0 0x0 0x1 0x32 0x0 0x2 0x2b 0x87 0x16 0xd9 0x9a 0x75 0x40 0x8 0x33 0x0 0x0 0x0 0x8 0x61 0x74 0x74 0x72 0x42 0x6f 0x6f 0x6c 0x65 0x61 0x6e 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x49 0x6e 0x74 0x33 0x32 0x0 0xc 0x0 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x4e 0x75 0x6d 0x62 0x65 0x72 0x0 0x7b 0x0 0x0 0x0 0x2 0x61 0x74 0x74 0x72 0x53 0x74 0x72 0x69 0x6e 0x67 0x0 0x9 0x0 0x0 0x0 0x61 0x20 0x73 0x74 0x72 0x69 0x6e 0x67 0x0 0x0 0x19 0x0 0x0 0x0 0x2 0x0 0xe 0x0 0x0 0x0 0x6a 0x75 0x73 0x74 0x20 0x61 0x20 0x73 0x74 0x72 0x69 0x6e 0x67 0x0 0x0",
				HelperByteArray.byteArrayToString(ba));
			
			// Add one doc with one _id valued
			h = new MongoMsgInsert("dbName", "collectionName", true);
			h.requestID = 123;
			var doc1:TestObjectIDVO = new TestObjectIDVO(ObjectID.createFromString("myId"));
			// One other doc with null _id
			var doc2:TestObjectIDVO = new TestObjectIDVO();
			h.addDocument(doc1);
			h.addDocument(doc2);
			try {
				
				ba = h.toBSON();
				// OK
			} catch (e:ExceptionJMCNetMongoDB) {
				Assert.fail("We should be able to Insert with 2 documents with ObjectID");
			}
			Assert.assertNotNull(doc1._id);
			Assert.assertNotNull(doc2._id);
			// The id was generated
			// We modify it in order to have a prectible result
			doc2._id = ObjectID.createFromString("my2ndObjectID");
			ba = h.toBSON();
			
			Assert.assertEquals(
				"0x74 0x0 0x0 0x0 0x7b 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0xd2 0x7 0x0 0x0 0x1 0x0 0x0 0x0 0x64 0x62 0x4e 0x61 0x6d 0x65 0x2e 0x63 0x6f 0x6c 0x6c 0x65 0x63 0x74 0x69 0x6f 0x6e 0x4e 0x61 0x6d 0x65 0x0 0x25 0x0 0x0 0x0 0x7 0x5f 0x69 0x64 0x0 0x0 0x4 0x6d 0x79 0x49 0x64 0x0 0x0 0x0 0x0 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x49 0x6e 0x74 0x33 0x32 0x0 0x0 0x0 0x0 0x0 0x0 0x25 0x0 0x0 0x0 0x7 0x5f 0x69 0x64 0x0 0x0 0xd 0x6d 0x79 0x32 0x6e 0x64 0x4f 0x62 0x6a 0x65 0x63 0x10 0x61 0x74 0x74 0x72 0x49 0x6e 0x74 0x33 0x32 0x0 0x0 0x0 0x0 0x0 0x0",
				HelperByteArray.byteArrayToString(ba));
		}
		
		/**
		 * Test HelperByteArray
		 */
		[Test]
		public function testHelperByteArraySimple():void {
			var dh:HelperDate = new HelperDate();
			Assert.assertEquals("{\n     : \"Une chaine\"\n}", HelperByteArray.bsonDocumentToReadableString(BSONEncoder.encodeObjectToBSON("Une chaine")));
			Assert.assertEquals("{\n     : 12\n}", HelperByteArray.bsonDocumentToReadableString(BSONEncoder.encodeObjectToBSON(12)));
			var d:Date = dh.stringToDate("21/12/2012");
			Assert.assertEquals("{\n     : Fri Dec 21 00:00:00 GMT+0100 2012\n}", HelperByteArray.bsonDocumentToReadableString(BSONEncoder.encodeObjectToBSON(d)));
			Assert.assertEquals("{\n     : true\n}", HelperByteArray.bsonDocumentToReadableString(BSONEncoder.encodeObjectToBSON(true)));
			Assert.assertEquals("{\n     : false\n}", HelperByteArray.bsonDocumentToReadableString(BSONEncoder.encodeObjectToBSON(false)));
		}
			
		[Test]
		public function testHelperByteArrayObject():void {
			var testVo:TestVO = new TestVO("une chaîne",12,123.456, true);
			var result:ByteArray = BSONEncoder.encodeObjectToBSON(testVo);
			var resStr:String = HelperByteArray.bsonDocumentToReadableString(result);
			log.debug("testHelperByteArray : resStr=\n'"+resStr+"'");
			var expectedResult:String=
									"{\n"+
									"    attrArray : [\n"+
									"            0 : \"arrayStringValue\",\n"+
									"            1 : 14,\n"+
									"            2 : 345.678,\n"+
									"            3 : false\n"+
									"     ],\n"+
									"    attrBoolean : true,\n"+
									"    attrInt32 : 12,\n"+
									"    attrNumber : 123.456,\n"+
									"    attrString : \"une chaîne\"\n"+
									"}";
			Assert.assertEquals(expectedResult, resStr);
		}
		
		[Test]
		public function testMongoDocumentQuery():void {
			var query:MongoDocumentQuery = new MongoDocumentQuery();
			query.addQueryCriteria("attr1", "value1");
			query.addQueryCriteria("attr2", "value2");
			
			query.addOrderByCriteria("attr1", true);
			query.addOrderByCriteria("attr2", false);
			
			var bson:ByteArray = query.toBSON();
			log.debug("testMongoDocumentQuery bson="+HelperByteArray.byteArrayToString(bson));
			
			var resStr:String = HelperByteArray.bsonDocumentToReadableString(bson);
			log.debug("testHelperByteArray : resStr=\n'"+resStr+"'");
			var expectedResult:String=
				"{\n"+
				"    $query : {\n" +
				"            attr1 : \"value1\",\n"+
				"            attr2 : \"value2\"\n"+
				"     },\n"+
				"    $orderby : {\n"+
				"            attr1 : 1,\n"+
				"            attr2 : -1\n"+
				"     }\n"+
				"}";
			
			Assert.assertEquals(expectedResult, resStr);
		}
		
		[Test]
		public function testMongoMsgQuery():void {
			var query:MongoDocumentQuery = new MongoDocumentQuery();
			
			query.addQueryCriteria("attr1", "value1");
			query.addQueryCriteria("attr2", "value2");
			
			query.addOrderByCriteria("attr1", true);
			query.addOrderByCriteria("attr2", false);
			
			var msg:MongoMsgQuery = new MongoMsgQuery("dbName","collectionName");
			msg.query = query;
			msg.requestID = 123;
			
			// msg.returnFieldsSelector = new MongoDocument();
			
			var bson:ByteArray = msg.toBSON();
			log.debug("testMongoDocumentQuery bson="+HelperByteArray.byteArrayToString(bson));
			
			var expectedResult:String="0x8d 0x0 0x0 0x0 0x7b 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0xd4 0x7 0x0 0x0 0x0 0x0 0x0 0x0 0x64 0x62 0x4e 0x61 0x6d 0x65 0x2e 0x63 0x6f 0x6c 0x6c 0x65 0x63 0x74 0x69 0x6f 0x6e 0x4e 0x61 0x6d 0x65 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0x5b 0x0 0x0 0x0 0x3 0x24 0x71 0x75 0x65 0x72 0x79 0x0 0x29 0x0 0x0 0x0 0x2 0x61 0x74 0x74 0x72 0x31 0x0 0x7 0x0 0x0 0x0 0x76 0x61 0x6c 0x75 0x65 0x31 0x0 0x2 0x61 0x74 0x74 0x72 0x32 0x0 0x7 0x0 0x0 0x0 0x76 0x61 0x6c 0x75 0x65 0x32 0x0 0x0 0x3 0x24 0x6f 0x72 0x64 0x65 0x72 0x62 0x79 0x0 0x1b 0x0 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x31 0x0 0x1 0x0 0x0 0x0 0x10 0x61 0x74 0x74 0x72 0x32 0x0 0xff 0xff 0xff 0xff 0x0 0x0";
			Assert.assertEquals(expectedResult, HelperByteArray.byteArrayToString(bson));
		}
		
		[Test]
		public function testMongoMsgUpdate():void {
			var update:MongoDocumentUpdate = new MongoDocumentUpdate();
			
			update.addUpdateCriteria("attr1", "value1");
			update.addUpdateCriteria("attr2", "value2");
			
			update.addSelectorCriteria("attr1", true);
			update.addSelectorCriteria("attr2", false);
			
			var msg:MongoMsgUpdate = new MongoMsgUpdate("dbName","collectionName");
			msg.update = update;
			msg.requestID = 123;
			
			Assert.assertEquals(123, msg.requestID);
			Assert.assertFalse(msg.isUpsert());
			Assert.assertFalse(msg.isMultiUpdate());
			msg.setFlags(true, true);
			Assert.assertTrue(msg.isUpsert());
			Assert.assertTrue(msg.isMultiUpdate());
			
			var bson:ByteArray = msg.toBSON();
			log.debug("testMongoMsgUpdate bson="+HelperByteArray.byteArrayToString(bson));
			
			var expectedResult:String="0x6c 0x0 0x0 0x0 0x7b 0x0 0x0 0x0 0x0 0x0 0x0 0x0 0xd1 0x7 0x0 0x0 0x0 0x0 0x0 0x0 0x64 0x62 0x4e 0x61 0x6d 0x65 0x2e 0x63 0x6f 0x6c 0x6c 0x65 0x63 0x74 0x69 0x6f 0x6e 0x4e 0x61 0x6d 0x65 0x0 0x3 0x0 0x0 0x0 0x15 0x0 0x0 0x0 0x8 0x61 0x74 0x74 0x72 0x31 0x0 0x1 0x8 0x61 0x74 0x74 0x72 0x32 0x0 0x0 0x0 0x29 0x0 0x0 0x0 0x2 0x61 0x74 0x74 0x72 0x31 0x0 0x7 0x0 0x0 0x0 0x76 0x61 0x6c 0x75 0x65 0x31 0x0 0x2 0x61 0x74 0x74 0x72 0x32 0x0 0x7 0x0 0x0 0x0 0x76 0x61 0x6c 0x75 0x65 0x32 0x0 0x0";
			                           
			Assert.assertEquals(expectedResult, HelperByteArray.byteArrayToString(bson));
		}
		
		[Test]
		public function testBSONDecoder():void {
			var testVo:TestVO = new TestVO("une chaîne",12,123.456, true);
			var bson:ByteArray = BSONEncoder.encodeObjectToBSON(testVo);
			
			bson.position=0;
			var doc:MongoDocument = BSONDecoder.decodeBSONToMongoDocument(bson);
			Assert.assertNotNull(doc);
			Assert.assertEquals(testVo.attrBoolean, doc.getValue("attrBoolean"));
			Assert.assertEquals(testVo.attrInt32, doc.getValue("attrInt32"));
			Assert.assertEquals(testVo.attrString, doc.getValue("attrString"));
			Assert.assertEquals(testVo.attrArray.toString(), doc.getValue("attrArray").toString());
		}
		
		[Test]
		public function testGetObjectAttributes():void {
			var attr:HashTable = HelperClass.getObjectAttributes(new TestVO());
			Assert.assertEquals(5 ,attr.length);
			Assert.assertEquals("attrArray", attr.getKeyAt(0));
			Assert.assertEquals("attrBoolean", attr.getKeyAt(1));
			Assert.assertEquals("attrInt32", attr.getKeyAt(2));
			Assert.assertEquals("attrNumber", attr.getKeyAt(3));
			Assert.assertEquals("attrString", attr.getKeyAt(4));
		}
		
		[Test]
		public function testDocumentToObject():void {
			var doc:MongoDocument = new MongoDocument();
			doc.addKeyValuePair("attrString", "myString");
			doc.addKeyValuePair("attrInt32", 12);
			doc.addKeyValuePair("attrBoolean", true);
			doc.addKeyValuePair("attrArray", new Array("String1", "String2"));
			
			var vo:TestVO = doc.toObject(TestVO);
			Assert.assertEquals("myString", vo.attrString);
			Assert.assertEquals(12, vo.attrInt32);
			Assert.assertEquals(true, vo.attrBoolean);
			Assert.assertEquals(2, vo.attrArray.length);
			Assert.assertEquals("String1", vo.attrArray[0]);
			Assert.assertEquals("String2", vo.attrArray[1]);
		}
		
		[Test]
		public function testComplexDocumentToObject():void {
			var testvo:TestVO = new TestVO("One String", 19, 123.456, false);
			var testvo1:TestVO = new TestVO("2nd String", 20, 124.456, true);
			var testvo2:TestVO = new TestVO("3rd String", 21, 125.456, false);
			var doc:MongoDocument = new MongoDocument();
			doc.addKeyValuePair("attrInt32", 18);
			doc.addKeyValuePair("testvo", testvo);
			doc.addKeyValuePair("arrayTestvo", new Array(testvo1, testvo2));
			
			var vo:TestComplexObjectIDVO = doc.toObject(TestComplexObjectIDVO);
			Assert.assertEquals(18, vo.attrInt32);
			
			Assert.assertNotNull(vo.testvo);
			Assert.assertEquals(19, vo.testvo.attrInt32);
			Assert.assertEquals("One String", vo.testvo.attrString);
			Assert.assertEquals(123.456, vo.testvo.attrNumber);
			Assert.assertFalse(vo.testvo.attrBoolean);
			
			Assert.assertEquals(2, vo.arrayTestvo.length);
			Assert.assertEquals(20, vo.arrayTestvo[0].attrInt32);
			Assert.assertEquals("2nd String", vo.arrayTestvo[0].attrString);
			Assert.assertEquals(124.456, vo.arrayTestvo[0].attrNumber);
			Assert.assertTrue(vo.arrayTestvo[0].attrBoolean);
			
			Assert.assertEquals(21, vo.arrayTestvo[1].attrInt32);
			Assert.assertEquals("3rd String", vo.arrayTestvo[1].attrString);
			Assert.assertEquals(125.456, vo.arrayTestvo[1].attrNumber);
			Assert.assertFalse(vo.arrayTestvo[1].attrBoolean);			
		}
		
		// Store this object in a MongoDB instance
		private var driver:JMCNetMongoDBDriver = new JMCNetMongoDBDriver();
		private var obj:TestComplexObjectIDVO;
		
		[Test(async, timeout=5000)]
		public function testComplexObject():void {
			log.debug("Calling testComplexObject");
			var testvo:TestVO = new TestVO("One String", 19, 123.456, false);
			var testvo1:TestVO = new TestVO("2nd String", 20, 124.456, true);
			var testvo2:TestVO = new TestVO("3rd String", 21, 125.456, false);
			var testvo3:TestVO = new TestVO("4rd String", 22, 126.456, true);
			obj = new TestComplexObjectIDVO(ObjectID.createFromString("myObject"), 16, testvo, new Array(testvo1, testvo2), new Array(testvo3));
			
			driver.databaseName = DATABASENAME;
			driver.hostname = SERVER;
			driver.port = PORT;
			driver.username = USERNAME;
			driver.password = PASSWORD;
			driver.setWriteConcern(JMCNetMongoDBDriver.SAFE_MODE_NORMAL);
			Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_CONNECTOK, onConnect1, 1000);
			Async.failOnEvent(this, driver, JMCNetMongoDBDriver.EVT_AUTH_ERROR, 1000);
			driver.connect();
		}
		
		public function onConnect1(event:EventMongoDB, ... args):void {
			log.debug("Calling onConnect1");
			// We are connected, so write the doc
			driver.insertDoc("testu", [obj]);
			
			// Wait a sec
			var t:Timer = new Timer(1000, 1);
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, onTimer1, 2000);
		}
		
		public function onTimer1(event:TimerEvent, ... args):void {
			log.debug("Calling onTimer1");
			// Find the doc
			Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_RESPONSE_RECEIVED, onResponseReceived1, 1000);
			var query:MongoDocumentQuery=new MongoDocumentQuery();
			query.addQueryCriteria("_id", ObjectID.createFromString("myObject"));
			driver.queryDoc("testu", query);
		}
		
		public function onResponseReceived1(event:EventMongoDB, ... args):void {
			log.debug("Calling onResponseReceived response="+ (event == null ? "null":event.result as MongoDocumentResponse));
			
			var rep:MongoDocumentResponse = event.result as MongoDocumentResponse;
			Assert.assertEquals(1, rep.numberReturned);
			Assert.assertEquals(1, rep.documents.length);
			
			log.debug("Received doc : "+rep.documents[0].toString());
			var vo:TestComplexObjectIDVO = rep.documents[0].toObject(TestComplexObjectIDVO);
			Assert.assertEquals("00086d794f626a6563740000", vo._id.toString());
			Assert.assertEquals(16, vo.attrInt32);
			
			Assert.assertNotNull(vo.testvo);
			Assert.assertTrue(vo.testvo is TestVO);
			Assert.assertEquals(19, vo.testvo.attrInt32);
			Assert.assertEquals("One String", vo.testvo.attrString);
			Assert.assertEquals(123.456, vo.testvo.attrNumber);
			Assert.assertFalse(vo.testvo.attrBoolean);
			
			Assert.assertEquals(2, vo.arrayTestvo.length);
			// here wa have send TestVO but we only get an Object in return because Array are not typed
			Assert.assertTrue(vo.arrayTestvo[0] is Object);
			Assert.assertEquals(20, vo.arrayTestvo[0].attrInt32);
			Assert.assertEquals("2nd String", vo.arrayTestvo[0].attrString);
			Assert.assertEquals(124.456, vo.arrayTestvo[0].attrNumber);
			Assert.assertTrue(vo.arrayTestvo[0].attrBoolean);
			
			Assert.assertTrue(vo.arrayTestvo[1] is Object);
			Assert.assertEquals(21, vo.arrayTestvo[1].attrInt32);
			Assert.assertEquals("3rd String", vo.arrayTestvo[1].attrString);
			Assert.assertEquals(125.456, vo.arrayTestvo[1].attrNumber);
			Assert.assertFalse(vo.arrayTestvo[1].attrBoolean);
			
			Assert.assertEquals(1, vo.typeArrayTestvo.length);
			// here wa have a send TestVO and we get a real TestVO in return !!
			Assert.assertTrue(vo.typeArrayTestvo[0] is TestVO);
			Assert.assertEquals(22, vo.typeArrayTestvo[0].attrInt32);
			Assert.assertEquals("4rd String", vo.typeArrayTestvo[0].attrString);
			Assert.assertEquals(126.456, vo.typeArrayTestvo[0].attrNumber);
			Assert.assertTrue(vo.typeArrayTestvo[0].attrBoolean);
		}
		
		[Test]
		public function testObjectIDFromByte():void {
			var o1:ObjectID = new ObjectID();
			var str:String = o1.toString();
			var o2:ObjectID = ObjectID.fromStringRepresentation(str);
			trace("o1="+o1.toString()+" o2="+o2.toString());
			Assert.assertEquals(o1.toString(), o2.toString());
		}
		
		[Test(async, timeout=5000)]
		public function testOrderBy():void {
			log.debug("Calling testOrderBy");
			driver.databaseName = DATABASENAME;
			driver.hostname = SERVER;
			driver.port = PORT;
			driver.username = USERNAME;
			driver.password = PASSWORD;
			driver.setWriteConcern(JMCNetMongoDBDriver.SAFE_MODE_NORMAL);
			Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_CONNECTOK, onConnect2, 1000);
			Async.failOnEvent(this, driver, JMCNetMongoDBDriver.EVT_AUTH_ERROR, 1000);
			driver.connect();
		}
		
		public function onConnect2(event:EventMongoDB, ... args):void {
			log.debug("Calling onConnect2");
			// We are connected, so write the doc
			var testvo:TestVO = new TestVO("String1", 20, 123.456, false);
			var testvo1:TestVO = new TestVO("String2", 21, 124.456, true);
			var testvo2:TestVO = new TestVO("String3", 19, 125.456, false);
			
			driver.insertDoc("testu", [testvo, testvo1, testvo2]);
			
			// Wait a sec
			var t:Timer = new Timer(1000, 1);
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, onTimer2, 2000);
		}
		
		public function onTimer2(event:TimerEvent, ... args):void {
			log.debug("Calling onTimer2");
			// Find the doc
			Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_RESPONSE_RECEIVED, onResponseReceived2, 1000);
			var query:MongoDocumentQuery=new MongoDocumentQuery();
			// query.addQueryCriteria("attrString", "String");
			query.addOrderByCriteria("attrInt32", true);
			driver.queryDoc("testu", query);
		}
		
		public function onResponseReceived2(event:EventMongoDB, ... args):void {
			log.debug("Calling onResponseReceived2");
			
			var rep:MongoDocumentResponse = event.result as MongoDocumentResponse; 
			Assert.assertEquals(3, rep.documents.length);
			
			log.debug("Received doc[0] : "+rep.documents[0].toString());
			log.debug("Received doc[1] : "+rep.documents[1].toString());
			log.debug("Received doc[2] : "+rep.documents[2].toString());
			var vo1:TestVO = rep.documents[0].toObject(TestVO);
			var vo2:TestVO = rep.documents[1].toObject(TestVO);
			var vo3:TestVO = rep.documents[2].toObject(TestVO);
			
			Assert.assertEquals(vo1.attrString, "String3");
			Assert.assertEquals(vo2.attrString, "String1");
			Assert.assertEquals(vo3.attrString, "String2");
			
			Assert.assertEquals(vo1.attrInt32, 19);
			Assert.assertEquals(vo2.attrInt32, 20);
			Assert.assertEquals(vo3.attrInt32, 21);
			
			// Dans l'ordre inverse
			Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_RESPONSE_RECEIVED, onResponseReceived3, 1000);
			var query:MongoDocumentQuery=new MongoDocumentQuery();
			// query.addQueryCriteria("attrString", "String");
			query.addOrderByCriteria("attrInt32", false);
			driver.queryDoc("testu", query);
		}
		
		public function onResponseReceived3(event:EventMongoDB, ... args):void {
			log.debug("Calling onResponseReceived3");
			
			
			var rep:MongoDocumentResponse = event.result as MongoDocumentResponse; 
			Assert.assertEquals(3, rep.documents.length);
			
			log.debug("Received doc[0] : "+rep.documents[0].toString());
			log.debug("Received doc[1] : "+rep.documents[1].toString());
			log.debug("Received doc[2] : "+rep.documents[2].toString());
			var vo1:TestVO = rep.documents[0].toObject(TestVO);
			var vo2:TestVO = rep.documents[1].toObject(TestVO);
			var vo3:TestVO = rep.documents[2].toObject(TestVO);
			
			Assert.assertEquals(vo1.attrString, "String2");
			Assert.assertEquals(vo2.attrString, "String1");
			Assert.assertEquals(vo3.attrString, "String3");
			
			Assert.assertEquals(vo1.attrInt32, 21);
			Assert.assertEquals(vo2.attrInt32, 20);
			Assert.assertEquals(vo3.attrInt32, 19);
		}
		
		[Test(async, timeout=5000)]
		public function testOrderByReturnFields():void {
			log.debug("Calling testOrderByReturnFields");
			driver.databaseName = DATABASENAME;
			driver.hostname = SERVER;
			driver.port = PORT;
			driver.username = USERNAME;
			driver.password = PASSWORD;
			driver.setWriteConcern(JMCNetMongoDBDriver.SAFE_MODE_NORMAL);
			Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_CONNECTOK, onConnectOrderByReturnFields, 1000);
			Async.failOnEvent(this, driver, JMCNetMongoDBDriver.EVT_AUTH_ERROR, 1000);
			driver.connect();
		}
		
		public function onConnectOrderByReturnFields(event:EventMongoDB, ... args):void {
			log.debug("Calling onConnectOrderByReturnFields");
			// We are connected, so write the doc
			var testvo:TestVO = new TestVO("String1", 20, 123.456, false);
			var testvo1:TestVO = new TestVO("String2", 21, 124.456, true);
			var testvo2:TestVO = new TestVO("String3", 19, 125.456, false);
			
			driver.insertDoc("testu", [testvo, testvo1, testvo2]);
			
			// Wait a sec
			var t:Timer = new Timer(1000, 1);
			t.start();
			Async.handleEvent(this, t, TimerEvent.TIMER, onTimerOrderByReturnFields, 2000);
		}
		
		public function onTimerOrderByReturnFields(event:TimerEvent, ... args):void {
			log.debug("Calling onTimerOrderByReturnFields");
			// Find the doc
			var query:MongoDocumentQuery=new MongoDocumentQuery();
			query.addOrderByCriteria("attrInt32", true);
			// Ask for "attrString" attribute only
			driver.queryDoc("testu", query, onResponseReceivedOrderByReturnFields, new MongoDocument("attrString", 1));
		}
		
		public function onResponseReceivedOrderByReturnFields(rep:MongoDocumentResponse):void {
			log.debug("Calling onResponseReceivedOrderByReturnFields responseDoc="+rep);
			
			Assert.assertEquals(3, rep.documents.length);
			
			log.debug("Received doc[0] : "+rep.documents[0].toString());
			log.debug("Received doc[1] : "+rep.documents[1].toString());
			log.debug("Received doc[2] : "+rep.documents[2].toString());
			var vo1:MongoDocument = rep.documents[0] as MongoDocument;
			var vo2:MongoDocument = rep.documents[1] as MongoDocument;
			var vo3:MongoDocument = rep.documents[2] as MongoDocument;
			
			// Verify that doc are in order
			Assert.assertEquals(vo1.getValue("attrString"), "String3");
			Assert.assertEquals(vo2.getValue("attrString"), "String1");
			Assert.assertEquals(vo3.getValue("attrString"), "String2");
			
			// Verify that there is only attrString attribute
			Assert.assertNull(vo1.getValue("attrInt32"));
			Assert.assertNull(vo1.getValue("attrNumber"));
			Assert.assertNull(vo1.getValue("attrBoolean"));
			Assert.assertNull(vo1.getValue("attrArray"));
		}
		
		[Test(async, timeout=5000)]
		public function testAuthenticationNok():void {
			log.debug("Calling testAuthenticationNok");
			driver.databaseName = DATABASENAME;
			driver.hostname = SERVER;
			driver.port = PORT;
			driver.username = USERNAME;
			driver.password = "badPassword";
			driver.setWriteConcern(JMCNetMongoDBDriver.SAFE_MODE_NORMAL);
			Async.handleEvent(this, driver, JMCNetMongoDBDriver.EVT_AUTH_ERROR, onAuthError, 1000);
			Async.failOnEvent(this, driver, JMCNetMongoDBDriver.EVT_CONNECTOK, 1000);
			driver.connect();
		}
		
		private function onAuthError(event:EventMongoDB, ... args):void {
			log.debug("Received an expected EVT_AUTH_ERROR");
		}
	}
}