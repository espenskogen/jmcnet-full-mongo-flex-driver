package jmcnet.mongodb.driver
{
	import flash.errors.IllegalOperationError;
	import flash.utils.getQualifiedClassName;
	
	import jmcnet.mongodb.documents.ObjectID;

	/**
	 * Abstract class. Can be extended if you need a _id attribute to store the MongoDB _id ObjectID. You can also declare a _id attribute in your class
	 */
	public class ObjectIDable
	{
		public var _id:ObjectID;
		
		public function ObjectIDable(_id:ObjectID=null) {
			if ( getQualifiedClassName(super) == "ObjectIDable" )
				throw new IllegalOperationError("The class ObjectIDable is abstract and cannot be instanciated.");
			this._id = _id;
		}
	}
}