package 
{
	import jmcnet.mongodb.driver.EventMongoDB;
	import jmcnet.mongodb.driver.JMCNetMongoDBDriver;
	

	public class MongoDBConnManager
	{
		
		private static const hostName:String =  "jmcsrv2"; // "keeka03-w71"; //"localhost"; //"127.0.0.1";
		private static const dbName:String = "testDatabase"; // "crm";
		
		/*
		private static const dbPortNumber:int = 3306;
		private static const userName:String = "root";
		private static const password:String = "root";
		*/
		private static const userName:String = "jmc";
		private static const password:String = "jmc";
		
		static var mongoDriver:JMCNetMongoDBDriver = null;
		
		public static function getMongoConnection():JMCNetMongoDBDriver
		{ 
			mongoDriver = new JMCNetMongoDBDriver();
			
			mongoDriver.hostname = hostName;
			mongoDriver.databaseName = dbName;
				
			mongoDriver.addEventListener(JMCNetMongoDBDriver.EVT_CONNECTOK, onConnectOK); 
			//mongoDriver.addEventListener(JMCNetMongoDBDriver.EVT_LAST_ERROR, onConnectOK);
			
			mongoDriver.connect(); 
								 
			return mongoDriver;
		}
		
		protected static function onConnectOK(event:EventMongoDB):void {        
			// connected to MongoDB server         
			if (mongoDriver.isConnecte()) { 
								
			}
		}
	}
}