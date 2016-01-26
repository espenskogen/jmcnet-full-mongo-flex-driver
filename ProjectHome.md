## A full Flex/Flash AS3 Driver for MongoDB database V 2.0, 2.1, 2.2.rc1, 2.2 ##

Connect your AS3 application directly to a MongoDB database. Now you don't need a middleware to access your data.

Main features of the driver are :
  1. Connexion pooling,
  1. Auth mode compatibility,
  1. Safe mode enabling,
  1. Direct CRUD object manipulation,
  1. Full Aggregation support (group, MapReduce, ...),
  1. BSON encoder and decoder,
  1. ObjectID helper

**New with 2.0 :**
  1. Native support for generic object [DirectObject#Using\_generic\_object\_while\_inserting\_and\_querying](DirectObject#Using_generic_object_while_inserting_and_querying.md),
  1. New aggregation framework helpers [AggregationFramework](AggregationFramework.md),
  1. DBRef support and automatic DBRef deferencement with cross database DBRef possibility [DBRef](DBRef.md),
  1. Testing via FlexUnit and logging capabilities [TestingAndLogging](TestingAndLogging.md).

See [wiki](Home.md) documentation for more information or the test application provided to show uses cases ([source/browse/MongoDBTest](http://code.google.com/p/jmcnet-full-mongo-flex-driver/source/browse/)).

The complete source of FlexUnit testing is also provided in [source/browse/JMCNetMongoFlex\_Test](http://code.google.com/p/jmcnet-full-mongo-flex-driver/source/browse/).

**Forum** : you can interact with us in the [Community forum](https://groups.google.com/d/forum/jmcnet-full-mongo-flex-driver).

## V 2.1-SNAPSHOT Enhancements ##
  * correct [issue15](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=15) (suppress unwanted .toString()
  * correct [issue16](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=16) (option not to call .toObject() for performance issue),
  * correct [issue18](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=18) (multiple update modifiers now possible),
  * add response to [issue17](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=17).
  * Add Synchrone Runner class to unable synchrone message sending. See [handling synchrone messages](SynchroneMessageHandling.md),
  * Correct CollectionInterpreter for operation on collection.

## V 2.0 Enhancements ##
  1. Adding native support of generic object like Object and ArrayCollection in DirectObject. See [DirectObject#Using\_generic\_object\_while\_inserting\_and\_querying](DirectObject#Using_generic_object_while_inserting_and_querying.md) for more informations.
  1. Adding Responder and Token capabilities to driver's calls. This is more standard and so you can now give a token in the call which is given back in the callback. **Be careful, this enhancement leads to break compatibility with previous version of the driver.**. Hopefully, changes are easy to correct and are documented in the wiki. See [Responder](Responder.md) and [PortabilityNotes](PortabilityNotes.md) for more informations.
  1. Add response interpreter to make response decoding very much simplier. For example, mapReduce and aggregation has "results", group has "retval", distinct has "values" for return values.
  1. Add the support of the new aggregation framework with helpers. New operator must be also provided to complete the aggregation framework.
  1. Add helpers for full DBRef support and automatic deferencement upon find documents.
  1. Add multi-driver capabilities. Use one driver per database and DBRef cross databases support. See [DriverInitialization#Multiple\_drivers\_manipulations](DriverInitialization#Multiple_drivers_manipulations.md),
  1. Add a FlexUnit base class which provide easy testing capabilities. See [TestingAndLogging](TestingAndLogging.md),
  1. Enforce logging capabilities to make debug easier. See [TestingAndLogging](TestingAndLogging.md),
  1. Compatibility with MongoDB 2.2 server,
  1. Issues : [issue 5](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=5), [issue 8](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=8), [issue 10](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=10), [issue 12](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=12), [issue 11](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=11), [issue 7](https://code.google.com/p/jmcnet-full-mongo-flex-driver/issues/detail?id=7).
Note : this release must be used with the V 1.3 JMCNet libCommun library which can be found [here](http://code.google.com/p/jmcnet/downloads/detail?name=JMCNet_LibCommun-flex4-1.3.swc#makechanges).

## V 1.4 Enhancements ##
  * correct issue in auth mode when authentication event can be thrown after CONNECT\_OK event,
  * add a EVT\_AUTH\_ERROR event to easily handle case where authentication is NOK.
Tested with MongoDB 2.x in auth mode and in non auth mode.
Note : this release must be used with the V 1.2 JMCNet libCommun library.


## V1.3 Enhancements ##
  * correct "orderby" directive in MongoDocumentQuery,
  * add JUnit tests to verify "orderby" and "returnFields" attribute in driver.queryDoc.

## V1.2 Enhancements ##
  * add ObjectID.fromStringRepresentation method to initialize an ObjectID from its String representation,
  * correct ObjectID.toString method. If byte value < 17, no preceeding 0 was added leading to incorrect String representation.
See [ObjectID](ObjectID.md) for more information about ObjectID manipulation.

## V1.1 Enhancements ##
Makes the driver waits for free socket in the pool when the pool is empty. So you can configure your application with less socket in the pool. See [Driver initialization](DriverInitialization.md)

## Licensing ##
This library is available under 2 licensing mode :
  * GNU GPL V3 : you can freely use, redistribute, modify this code if your product is open source and GNU GPL too,
  * Commercial license : commercial applications can use this library without being open source but must paid a licensing fee. Contact me at `the[dot]jmcnet[dot]team[at]gmail[dot]com` for more information about this commercial license mode.


## They use our driver ##
Clouderial company uses our driver to [create an invoice online](https://www.clouderial.com/saas-applications.html) or to [create a quote online](https://www.clouderial.com/saas-applications.html).
La société Clouderial utilise nos services pour [creer une facture en ligne](https://www.clouderial.fr/saas-applications.html) ou [creer un devis en ligne](https://www.clouderial.fr/saas-applications.html).


## The JMCNet Team ##