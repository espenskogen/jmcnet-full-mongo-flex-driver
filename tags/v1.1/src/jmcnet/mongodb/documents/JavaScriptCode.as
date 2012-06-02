package jmcnet.mongodb.documents
{
	/**
	 * A Class holding JavaScript code. There is also Helpers to construct standard JavaScript
	 */
	public class JavaScriptCode
	{
		private var _code:String="";
		
		public function JavaScriptCode(code:String="", scoped:Boolean=false) { _code = code;}

		public function get code():String {	return _code; }
		public function set code(value:String):void { _code = value; }

		public function toString():String {	return "[JavaScriptCode : code="+(_code == null ? "null":(_code.substr(0, 20)+"..."))+"]"; }
	}
}