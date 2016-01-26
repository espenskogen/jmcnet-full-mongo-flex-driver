

# Introduction #
This page will explain, how to debug a application using the JMCNetMongoDBDriver and how to do some FlexUnit testing easily.

# Details #
## Debugging ##
All classes contained in this driver do logs. Logs can be seen from standard log output flex application (ie. Eclipse when running in debug mode, or FlashFireBug for example).
You can set the debug level in your main class as show in this example :
```
JMCNetLogger.setLogLevel(JMCNetLogger.DEBUG|JMCNetLogger.INFO|JMCNetLogger.EVT|JMCNetLogger.WARN|JMCNetLogger.ERROR);
```

You can also set fine debugging also for 3 kind of operations :
  1. log about document manipulation,
  1. log about BSON encoder and decoder,
  1. log about Socket pooling.

Those fine logs are activated by setting to true those attribute:
  1. driver.logBSON
  1. driver.logDocument
  1. driver.logSocketPool

You can add some logs into your application like shown in this example :
```
// Initialize logs (1rst parameter specify the localLog facility. Set it to true to enable local logs.
// The 2nd parameter is for using remote logging. See [http://code.google.com/p/jmcnet/] for more informations about remote logging.
JMCNetLogger.setLogEnabled(true, false);
// Set log level
JMCNetLogger.setLogLevel(JMCNetLogger.DEBUG);

...
// in each class you want to log 
private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(ClassName);

...
log.debug("Debug message");
log.info("Debug message");
log.evt("Debug message");
log.warn("Debug message");
log.error("Debug message");
...
```

## FlexUnit facility for JMCNetMongoDBDriver ##
For people who want to do some unit testing with this driver you can use this class _MongoBaseFlexUnitTest_ as base class for FlexUnit test class.
This provide :
  1. Automatic connection on startup,
  1. Automatic cleaning of test collection,
  1. Automatic disconnection on teardown,
  1. Automatic instanciation of _JMCNetMongoDBDriver_

Here is an example (browse tests source code for more example) :
```
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
		
		[Test(async, timeout=5000)]
		override public function myFirstTest():void {
			// here you are connected, authenticated and "testu" collection is cleaned.
		}
}
```

The base test class is not incorporated in the driver's swc not to force people to link with FlexUnit, but you can find it [here](http://code.google.com/p/jmcnet-full-mongo-flex-driver/source/browse/#svn%2Ftrunk%2FJMCNetMongoFlex_Test%2Fsrc).
Feel free to checkout it in your environment.

# See also #
  * [Home](Home.md),
  * [Installation](Installation.md),
  * [Driver initialization](DriverInitialization.md) (connection pooling, safe mode),
  * [Using responder](Responder.md),
  * [Collection manipulation](CollectionManipulation.md) (create, drop)

