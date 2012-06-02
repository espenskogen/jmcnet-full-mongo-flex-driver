package modele
{
	public class TestVO
	{
		public var attrString:String;
		public var attrInt32:uint;
		public var attrNumber:Number;
		public var attrBoolean:Boolean;
		public var attrArray:Array;
		
		public function TestVO(s:String=null, i:uint=0, n:Number=0, b:Boolean=false){
			this.attrString = s;
			this.attrInt32 = i;
			this.attrNumber = n;
			this.attrBoolean = b;
			this.attrArray = new Array();
			this.attrArray.push("arrayStringValue", 14, 345.678, false);
//			this.attr = ;
		}
	}
}