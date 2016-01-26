

# Introduction #

This project aims to provide to the community a full and reliable Flex Driver for [MongoDB](http://www.mongodb.org/). Some others initiatives exists, but I found it unusable in a professional environment.


# Details #

Main features are :
  1. Connexion pooling,
  1. Safe mode enabling,
  1. Direct CRUD object manipulation,
  1. Full Aggregation support (group, MapReduce, ...),
  1. BSON encoder and decoder,
  1. ObjectID helper,
**New with 2.0 :**
  1. Native support for generic object,
  1. New aggregation framework helpers,
  1. DBRef support and automatic DBRef deferencement with cross database DBRef possibility,
  1. Testing via FlexUnit and logging capabilities.

# Quick index #
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
  * [MapReduce](MapReduce.md),
  * [Direct object manipulation](DirectObject.md),
  * [Object Identifier](ObjectID.md),
  * [Aggregation framework](AggregationFramework.md),
  * [DBRef manipulation](DBRef.md),
  * [Testing and loggin capabilities](TestingAndLogging.md).

