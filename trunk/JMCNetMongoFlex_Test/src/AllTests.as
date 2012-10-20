package
{
	import junit.MongoAggregationTest;
	import junit.MongoCommandsTest;
	import junit.MongoDBRefTest;
	import junit.MongoDriverTest;
	import junit.MongoSyncRunnerSafeModeTest;
	import junit.MongoSyncRunnerTest;
	
	[Suite]
	[RunWith("org.flexunit.runners.Suite")]
	public class AllTests
	{
		public var test1:junit.MongoAggregationTest;
		public var test2:junit.MongoDBRefTest;
		public var test3:junit.MongoDriverTest;
		public var test4:junit.MongoSyncRunnerTest;
		public var test5:junit.MongoSyncRunnerSafeModeTest;
		public var test6:junit.MongoCommandsTest;
	}
}