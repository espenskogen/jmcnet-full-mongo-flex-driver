package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;

	public interface MongoMsgInterface {
		function toBSON():ByteArray;
	}
}