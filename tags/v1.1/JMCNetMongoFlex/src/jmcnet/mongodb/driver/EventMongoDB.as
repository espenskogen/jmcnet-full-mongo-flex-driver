package jmcnet.mongodb.driver
{
	import flash.events.Event;
	
	public class EventMongoDB extends Event
	{
		public var result:Object;
		public function EventMongoDB(type:String, result:Object=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			this.result = result;
		}
	}
}