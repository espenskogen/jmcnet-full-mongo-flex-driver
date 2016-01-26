

# Introduction #

This page will explain, how to group data in the result of a query. More explanations can be found @ MongoDB documentation [here](http://www.mongodb.org/display/DOCS/Aggregation#Aggregation-Group)

# Details #
To group results you must use the _group_ method of the driver. The _group_ method of the driver has the following signature :
```
/**
 * Retrieve documents and group them among a key.
 * @param collectionName (String) : the name of the collection to query from,
 * @param key (String) : the key used to group documents (see keyf param above),
 * @param reduce (JavaScriptCode) : a reduce JS function executed on the group. JS signature must be "function(obj, result):void",
 * @param initial (MongoDocument) : a list of key/value pairs used to initialize variables,
 * @param responder (MongoResponder) : the callback called when documents are ready to read. Default value is null,
 * @param keyf (JavaScriptCode) : a JS function used to calculate a key for grouping. keyf signature must be : "function(doc):{keyName: valueOfKeyForDoc}". Cf. One of key/keyf param must be provided. Default value is null,
 * @param cond (MongoDocument) : a document used to filter documents that will be grouped. Default value is null (all documents are considered),
 * @param finalize (JavaScriptCode) : a JS function used to finalize the result. JS signature must be "function(result):void". Default value is null (no finalization).
 */
public function group(collectionName:String, key:MongoDocument, reduce:JavaScriptCode, initial:MongoDocument,
	responder:MongoResponder, keyf:JavaScriptCode=null, cond:MongoDocument=null, finalize:JavaScriptCode=null):void
```

The result of a group command is a _MongoDocumentResponse_ in which there is only one document which _retval_ value contains an Array of result (build by _finalize_).

Example :
```
mongoDriver.group(
	"documentsCollectionName",
	null,
	new JavaScriptCode("function(obj, result) { result.count += obj.attrInt32; result.nb++; }"),
	new MongoDocument("count", 0).addKeyValuePair("nb",0).addKeyValuePair("avg", 0),
	new MongoResponder(onResponseReceived),
	new JavaScriptCode("function(doc) { return { \"attrString\" : doc.attrString }; }"),
	new MongoDocument("attrString",
		MongoDocument.exists(true)).
		addKeyValuePair("attrInt32",
			MongoDocument.exists(true)),
	new JavaScriptCode("function(result) { if (result.nb > 0) result.avg = result.count/result.nb; }")); 

...

private function onResponseReceived(responseDoc:MongoDocumentResponse, token:*):void {
	// with 1.4 syntax
	if (responseDoc.numberReturned == 1) {
		for each (var doc:MongoDocument in responseDoc.getDocument(0).getValue("retval")) {
			// do something with doc
		}
	}
	
	// With 2.0 syntax
	if (responDoc.isOk) {
		for each (var doc:Object in responseDoc.interpretedResponse) {
			// do something with doc
		}
	}
```

Please refers to MongoDB documentation to have more explanations and example of the _group_ command. [Here](http://www.mongodb.org/display/DOCS/Aggregation#Aggregation-Group).


# See also #
  * [Home](Home.md),
  * [Using responder](Responder.md),
  * [Query](Query.md) (Find, FindOne, getMore, killCursor),
  * [Count](Count.md),
  * [Distinct](Distinct.md),
  * [Group](Group.md),
  * [MapReduce](MapReduce.md),
  * [AggregationFramework](AggregationFramework.md)

