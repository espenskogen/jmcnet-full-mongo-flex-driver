

# Introduction #

This page will explain, how to modify your code between driver's release.

# Prior 1.4 to 2.0 #
2.0 release adds the Responder capabilities to driver. See [Responder](Responder.md).

You just need to transform this kind of call :
```
mongoDriver.driverMethod("documentsCollectionName", ..., onCallback);
```
on this (add new MongoResponder around the callback name) :
```
mongoDriver.driverMethod("documentsCollectionName", ..., new MongoResponder(onCallback));
```

and add a token parameter to all callbacks.
Change this :
```
public function onCallback(response:MongoDocumentResponse):void 
```
on this (add `token:*`) :
```
public function onCallback(response:MongoDocumentResponse, token:*):void 
```
Changes are not so hard to do...

# See also #
  * [Home](Home.md),
  * [Installation](Installation.md),
  * [Driver initialization](DriverInitialization.md) (connection pooling, safe mode),
  * [Using responder](Responder.md),
  * [Collection manipulation](CollectionManipulation.md) (create, drop),
  * [Running commands](SendingCommand.md),
  * [CRUD](CRUD.md) (Create, Retrieve, Update, Delete),
  * [Query](Query.md) (Find, FindOne, getMore, killCursor),
  * [Count](Count.md),
  * [Distinct](Distinct.md),
  * [Group](Group.md),
  * [MapReduce](MapReduce.md)

