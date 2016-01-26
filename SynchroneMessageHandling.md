

# Introduction #

MongoDB is a globally asynchrone database. You send message and you don't know when the answer will be available. For this reason, if you send 2 commands in differents socket, you are not able to be sure that first one will be treaten before second one.
This page will explain, how to send commands to MongoDB being sure that the order is respected. This is called synchrone runner capabilities.

# Details #
The synchronism is managed by the MongoSyncRunner class. Each class holds a fifo of command. You fill the fifo with the commands you want to execute. You call the _start_ method,
and all commands are executed, each waiting for the preceeding to be complete.
Each MongoSyncRunner communicate with !MongoDB with a unique socket to be sure that command are in order.

When all commands are send, the runner sends a message (EVT\_RUNNER\_COMPLETE if all commands are allright or EVT\_RUNNER\_ERROR in case of at least one error).
In the COMPLETE or ERROR handler, you get a array of all the results of each commands.

When a command is in error, the runner stops. Optionnaly you can tels the Runner to continue execution if an error occurs. This is done when instanciating the MongoSyncRunner.

## Responder and callback handling ##
For each command you push in the MongoSyncRunner we can have a responder. Callbacks of the responder will be called when the command completes (like normal commands sends by the driver directly).
More than this, when runner complete, you get an array of all the MongoDocumentResponse for all commands. It up to you to decide which way you want to handle the responses (or not...).

## Examples ##
Instanciating a MongoSyncRunner :
```
// Give the driver in parameter and a boolean named continueOnError which is true if the runner
// continue running in case of an error
var syncRunner:MongoSyncRunner = new MongoSyncRunner(driver, false);
```

Adding commands in the runner that will be executed synchronously :
```
syncRunner.createCollection("testu");
syncRunner.insertDoc("testu", [doc1], new MongoResponder(onInsertCallback, null, myToken)); // will be send after createCollection
syncRunner.updateDoc("testu",                                                               // will be send after insertDoc
	new MongoDocumentUpdate(
		MongoDocument.addKeyValuePair("author","bob"),
		MongoDocument.set("title","The new title")),
	null, false, false);
syncRunner.queryDoc(                                                                        // will be send after updateDoc
	"testu",
	new MongoDocumentQuery(MongoDocument.addKeyValuePair("_id", doc1._id)),
	new MongoResponder(onQueryCallback));
	
...
// Will be called when insertDoc complete (be carefull : only when safeMode is on)
private function onInsertCallback(response:MongoDocumentResponse, token:*):void {
	// token is myToken
	if (response.isOk) {
		// Do something when insertDoc is ok
	}
}

...
// Will be called when queryDoc complete
private function onQueryCallback(response:MongoDocumentResponse, token:*):void {
	if (response.isOk) {
		// Do something when queryDoc is ok
	}
}
```

Telling the runner to run :
```
syncRunner.addEventListener(MongoSyncRunner.EVENT_RUNNER_COMPLETE, onRunnerComplete);
syncRunner.addEventListener(MongoSyncRunner.EVENT_RUNNER_ERROR, onRunnerError);
syncRunner.start();

...
private function onRunnerComplete(event:EventMongoDB):void {
	// Runner must be OK
	assertTrue(syncRunner.isOk);
	// The array of MongoDocumentResponse (one for each command which has a response. Be carefull of safeMode...
	var tabResponse:Array = event.result as Array;
	var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
	assertTrue(response0.isOk);
	...
	var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
	assertTrue(response1.isOk);
	...
}

private function onRunnerError(event:EventMongoDB):void {
	// Runner must be KO
	assertFalse(syncRunner.isOk);
	// The array of MongoDocumentResponse (one for each command which has a response). Be carefull of safeMode...
	// The number of response depends on the continueOnError flags and on the safeMode of the driver.
	var tabResponse:Array = event.result as Array;
	var response0:MongoDocumentResponse = tabResponse[0] as MongoDocumentResponse;
	if (response0.isOk) // response0 was OK
	...
	var response1:MongoDocumentResponse = tabResponse[1] as MongoDocumentResponse;
	if (!response0.isOk) // response1 was KO
	...
}
```

For more information about Responder callback and interaction with safeMode, see [Using responder](Responder.md).

# See also #
  * [Home](Home.md),
  * [Using responder](Responder.md),
  * [Driver's initialisation and safeMode](DriverInitialization.md),
  * [Query](Query.md) (Find, getMore, killCursor),
  * [Count](Count.md),
  * [Distinct](Distinct.md),
  * [Group](Group.md),
  * [MapReduce](MapReduce.md),
  * [Responder](Responder.md)

