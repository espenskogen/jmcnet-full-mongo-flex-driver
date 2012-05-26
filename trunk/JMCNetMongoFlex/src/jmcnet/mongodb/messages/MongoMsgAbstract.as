package jmcnet.mongodb.messages
{
	import flash.utils.ByteArray;
	import flash.utils.getQualifiedClassName;
	
	import jmcnet.mongodb.bson.BSONEncoder;
	
	/**
	 * Some abstract method used by MongoDB messages
	 */
	public class MongoMsgAbstract implements MongoMsgInterface
	{
		private var _dbName:String;
		private var _collectionName:String;
		private var _header:MongoMsgHeader;
		
		public function MongoMsgAbstract(dbName:String, collectionName:String, opCode:uint) {
			if ( getQualifiedClassName(super) == "MongoMsgAbstract" )
				throw new UninitializedError("The class MongoMsgAbstract is abstract and cannot be instanciated.");
			_dbName = dbName;
			_collectionName = collectionName;
			_header = new MongoMsgHeader(opCode);
		}
		
		public function writeFullCollectionName(msg:ByteArray):void {
			msg.writeMultiByte(dbName+"."+collectionName, "utf-8");
			msg.writeByte(BSONEncoder.BSON_TERMINATOR);
		}
		
		public function writeMsgLength(msg:ByteArray):void {
			msg.position = 0;
			msg.writeUnsignedInt(msg.length);
		}
		
		public function toBSON():ByteArray {
			throw new UninitializedError("The abstract toBSON() method must be implemented");
		}
		
		public function get dbName():String	{ return _dbName;	}
		public function set dbName(value:String):void {	_dbName = value;}

		public function get collectionName():String{ return _collectionName;}
		public function set collectionName(value:String):void{	_collectionName = value;}
		
		public function get requestID():uint { return _header.requestID; }
		public function set requestID(value:uint):void { _header.requestID = value;	}
		
		public function getHeaderBSON():ByteArray {
			if (_header == null) return null;
			return _header.toBSON();
		}
	}
}