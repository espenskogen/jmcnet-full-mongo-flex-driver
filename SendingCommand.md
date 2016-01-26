

# Introduction #

This page will explain, how to send commands to the database.

# Details #

Sending command is done by the following method of the driver :
```
/**
 * Send a command to the database. A command has no result in return.
 * @param command (MongoDocument) : the command,
 * @param responder (Responder) : the responder called with command's results.
 * @param interpreter (MongoResponseInterpreter) : a interpretor class which exploit the result a transform this in MongoDocumentResponse.interpretedResponse object.
 */
public function runCommand(command:MongoDocument, responder:MongoResponder=null, interpreter:MongoResponseInterpreterInterface=null ):void
```

If provided, callback must have the following signature :
```
private function onResponseRunCommandReady (response:MongoDocumentResponse, token:*):void
```

If an _interpreter_ class is not provided, the driver uses a basic interpretor which just transform the response in generic object.
This generic result is available in _MongoDocumentResponse.interpretedResponse_.

## Default callback response for command ##
A more convenient way to catch command response is to add a listener to the driver. Then all _runCommand_ call without callback provided will call the listener.

Example :
```
...
mongoDriver.addEventListener(JMCNetMongoDBDriver.EVT_RUN_COMMAND, onRunCommand);
// this command will call onRunCommand
mongoDriver.runCommand(new MongoDocument("create",Constantes.documentsCollectionName), null);
// This command will call onResponseRunCommandReady but not onRunCommand
mongoDriver.runCommand(new MongoDocument("drop",Constantes.documentsCollectionName), onResponseRunCommandReady );
...

protected function onRunCommand(event:EventMongoDB):void {
	// result command is on event.result
	var response:MongoDocumentResponse = event.result as MongoDocumentResponse;
	// check response
}

protected function onResponseRunCommandReady (response:MongoDocumentResponse):void  {
...
}
```


# See also #
  * [Home](Home.md),
  * [Using responder](Responder.md),
  * [Collection manipulation](CollectionManipulation.md) (create, drop),
  * [Running commands](SendingCommand.md),
  * [CRUD](CRUD.md) (Create, Retrieve, Update, Delete)

