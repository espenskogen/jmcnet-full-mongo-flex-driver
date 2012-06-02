package modele
{
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.driver.ObjectIDable;
	
	public class TestObjectIDVO extends ObjectIDable
	{
		public var attrInt32:uint;
		
		public function TestObjectIDVO(_id:ObjectID=null, i:uint=0){
			super(_id);
			this.attrInt32 = i;
		}
	}
}