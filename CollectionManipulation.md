

# Details #

Manipulating collections is very easy.
Just call one of these free methods of the drivers :
```
// Create collection
public function createCollection(collectionName:String,  safeResponder:MongoResponder=null):void

// Drop collection
public function dropCollection(collectionName:String,  safeResponder:MongoResponder=null):void

// Rename collection
public function renameCollection(collectionName:String, newCollectionName:String, safeResponder:MongoResponder=null):void
```

_safeCallback_ is called by the driver when the answer is received from database.
It must be a method with these signature :
```
private function onResponseReady (response:MongoDocumentResponse, token:*):void {
	// Response is received
	if (response.isOK) {
		// do your work ...
	}
}
```

# See also #

  * [Home](Home.md)
  * [Using responder](Responder.md),
  * [Running commands](SendingCommand.md),
  * [CRUD](CRUD.md) (Create, Retrieve, Update, Delete),

