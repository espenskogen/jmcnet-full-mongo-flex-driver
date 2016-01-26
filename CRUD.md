

# Introduction #

This page will explain, how to do CRUD operations on collections.
More complete explanation about querying can be found [here](Query.md).


# Details #

== Creating a document in a collection
Creating can be done by calling this method of the driver :
```
/**
 * Insert one or more documents in a collection
 * @param collectionName (String) : the name of the collection to insert into,
 * @param documents (Array of Object or MongoDocument) : the objects to insert,
 * @param responder (MongoResponder) : the callback called when documents are inserted (cf. safe mode). Default value is null,
 * @param continueOnError (Boolean) : true if must continue when there is an error. Default value is false.
 */
public function insertDoc(collectionName:String, documents:Array, responder:MongoResponder=null, continueOnError:Boolean=true):void
```

Documents is an array of objects that will be inserted in the collection. Each object can be :
  * a MongoDocument object : a document,
  * a POFO (Plain Old Flex Object) : a "normal" object like value object. Cf. [Direct object manipulation](DirectObject.md) for more informations.
  * an Array of Object and/or ArrayCollection,
  * an native Flex object like String, int, Number, Date, Object, ArrayCollection, ...
  * any combination of the preceding types.

Examples :
```
// insert 2 TestVO object, don't wait for answer
mongoDriver.insertDoc("documentsCollectionName", [new TestVO("StringValue1",18,253.1234,true), new TestVO("StringOther2",19,254.1234,false)], null, true);

// Insert a native Flex Object, when done callbackMethod is called
var obj:Object = new Object();
obj.attr1 = 1;
obj.attrInt32=22;
obj._id = null;
mongoDriver.insertDoc("documentsCollectionName", [obj], responder, true);

// Insert a single String (key is '')
mongoDriver.insertDoc("documentsCollectionName", ["a simple String"]);

// Insert one document composed by an Array of two String
mongoDriver.insertDoc("documentsCollectionName", [new Array("1rst String", "2nd String")]);

// Insert an TestObjectIDVO with custom ObjectID provided
mongoDriver.insertDoc("documentsCollectionName", [new TestObjectIDVO(ObjectID.createFromString("myObjectIDString"))]);

// Insert a MongoDocument object
mongoDriver.insertDoc(Constantes.documentsCollectionName, [new MongoDocument("key", "value")]);

// Insert a generic object
private var doc1:Object = {
	title : "this is my first title" ,
	author : "bob" ,
	posted : d1,
	pageViews : 5 ,
	tags : [ "fun" , "good" , "fun" ] ,
	comments : [
		{ author :"joe" , text : "this is cool" } ,
		{ author :"sam" , text : "this is bad" }
	],
	other : { foo : 5 }
};
private var doc2:Object = {...};
private var doc3:Object = {...};
driver.insertDoc(Constantes.documentsCollectionName, [doc1, doc2, doc3]);

```

## Retrieving documents from a collection ##
Retrieving documents is done by calling the _queryDoc_ method of the driver :
```
/**
 * Query documents (ie. find, findOne, find.skip, find.limit).
 * @param collectionName (String) : the name of the collection to query from,
 * @param query (MongoDocumentQuery) : the query document,
 * @param responder (MongoResponder) : the callback called when documents are ready to read. Default value is null,
 * @param returnFields (MongoDocument) : list of field included in the response. Default is null (all fields are returned),
 * @param numberToSkip (uint) : number of docs to skip. Usefull for pagination. Default is 0,
 * @param numberToReturn (uint) : number of docs to return. Usefull for pagination. Default is 0 (returns default documents number),
 * @param taillableCursor (Boolean) : if true opens and returns a taillable cursor,
 * @param slaveOk (Boolean) : if true query can be send to an arbitrary slave,
 * @param noCursorTimeout (Boolean) : if true the cursor is never kill even if not use for a while,
 * @param awaitData (Boolean) : Use with TailableCursor. If we are at the end of the data, block for a while rather than returning no data. After a timeout period, we do return as normal.
 * @param exhaust (Boolean) : Stream the data down full blast in multiple "more" packages, on the assumption that the client will fully read all data queried. Faster when you are pulling a lot of data and know you want to pull it all down. Note: the client is not allowed to not read all the data unless it closes the connection.
 * @param partial (Boolean) : Get partial results from a mongos if some shards are down (instead of throwing an error) 
 **/
public function queryDoc(collectionName:String, query:MongoDocumentQuery, responder:MongoResponder=null, returnFields:MongoDocument=null,
		numberToSkip:uint=0, numberToReturn:int=0, tailableCursor:Boolean=false, slaveOk:Boolean=false, noCursorTimeout:Boolean=false,
		awaitData:Boolean=false, exhaust:Boolean=false, partial:Boolean=false ):void
```

Examples :
```
// find 10 first doc of a collection
mongoDriver.queryDoc("documentsCollectionName", new MongoDocumentQuery(), new MongoResponder(onResponseReceived), null, 0, 10 );

// all documents when "attrInt32 is greater than or equals to 19 and lower than 22
var query:MongoDocumentQuery = new MongoDocumentQuery();
query.addQueryCriteria("attrInt32", MongoDocument.gte(19).lt(22));
mongoDriver.queryDoc("documentsCollectionName", query, onResponseReceived);

// all documents where attrString like regexp
var query:MongoDocumentQuery = new MongoDocumentQuery();
query.addQueryCriteria("attrString",
	MongoDocument.regex("^string.*[12]$",true, false, false, false));
mongoDriver.queryDoc("documentsCollectionName", query, onResponseReceived); 

...
private function onResponseReceived(responseDoc:MongoDocumentResponse, token:*):void {
	// The documents in response
	for (var i:int=0; i < responseDoc.numberReturned; i++) {
		responseDoc.getDocument(i);
	}
...
}

```

More explanations on Querying can be found [here](Query.md).

## Updating documents ##
Updating is done by calling this driver's method :
```
/**
 * Update one or more documents of a collection.
 * @param collectionName (String) : the name of the collection,
 * @param update (MongoDocumentUpdate) : the update query and modifications,
 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
 * @param upsert (Boolean) : if true can perform an insert if doc don't exists. Default value is false,
 * @param multiupdate (Boolean) : if true can perform update one more than one document. Default value is false,
 */
public function updateDoc(collectionName:String, update:MongoDocumentUpdate, safeResponder:MongoResponder= null, upsert:Boolean=false, multiUpdate:Boolean=false)
```

Examples :
```
// Update all existing documents, set root.attrString="newValue"
var doc:MongoDocumentUpdate = new MongoDocumentUpdate();
doc.addUpdateCriteria("$set", new MongoDocument("root.attrString", "newValue"));
mongoDriver.updateDoc(Constantes.documentsCollectionName, doc, new MongoResponder(onResultCallback), false, true);

// Update one document, set root.attrInt32=256 where root.attrInt32=18
doc = new MongoDocumentUpdate();
doc.addUpdateCriteria("root.attrInt32", 256);
doc.addSelectorCriteria("root.attrInt32", 18);
mongoDriver.updateDoc(Constantes.documentsCollectionName, doc, new MongoResponder(callbackMethod), false, false);
```

## Deleting documents ##
To delete documents you call the following method on the driver object :
```
/**
 * Delete one or more documents of a collection.
 * @param collectionName (String) : the name of the collection,
 * @param delete (MongoDocumentDelete) : the delete query,
 * @param safeResponder (MongoResponder) : the callback called when getLastError is send and if safe mode is well valued (cf. safe mode). Default value is null,
 * @param singleRemove (Boolean) : if true perform a single remove. Default value is false.
 */
public function deleteDoc(collectionName:String, doc:MongoDocumentDelete, safeResponder:MongoResponder = null, singleRemove:Boolean=false):void
```

Examples :
```
// delete all docs where root.attrString = "newValue"
var doc:MongoDocumentDelete = new MongoDocumentDelete();
doc.addSelectorCriteria("root.attrString", "newValue");
mongoDriver.deleteDoc("documentsCollectionName", doc, responder, false);

// Delete the first doc where attrString1="newValue" OR attrString2="otherValue"
mongoDriver.deleteDoc(Constantes.documentsCollectionName,
	new MongoDocumentDelete(MongoDocument.or(
		new MongoDocument("attrString1", "newValue"),
		new MongoDocument("attrString2", "otherValue"))),
	new MongoResponder(myCallBack, myErrorCallback), true);
```

# See also #
  * [Home](Home.md),
  * [Using responder](Responder.md),
  * [Collection manipulation](CollectionManipulation.md) (create, drop),
  * [CRUD](CRUD.md) (Create, Retrieve, Update, Delete),
  * [Query](Query.md) (Find, FindOne, getMore, killCursor)
  * [ObjectID](ObjectID.md)

