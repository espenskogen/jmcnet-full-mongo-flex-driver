package junit
{
	import jmcnet.mongodb.documents.ObjectID;
	import jmcnet.mongodb.driver.ObjectIDable;
	
	public class TestComplexObjectIDVO extends ObjectIDable
	{
		public var attrInt32:uint;
		public var testvo:TestVO;
		public var arrayTestvo:Array;
		[ArrayElementType("junit::TestVO")]
		public var typeArrayTestvo:Array;
		
		public function TestComplexObjectIDVO(_id:ObjectID=null, i:uint=0, testvo:TestVO=null, arrayTestvo:Array=null, typeArrayTestvo:Array=null){
			super(_id);
			this.attrInt32 = i;
			this.testvo = testvo;
			this.arrayTestvo = arrayTestvo;
			this.typeArrayTestvo = typeArrayTestvo;
		}
	}
}
