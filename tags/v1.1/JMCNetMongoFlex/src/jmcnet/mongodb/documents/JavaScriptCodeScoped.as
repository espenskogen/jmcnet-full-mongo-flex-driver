package jmcnet.mongodb.documents
{
	/**
	 * A Class holding JavaScript code. There is also Helpers to construct standard JavaScript
	 */
	public class JavaScriptCodeScoped
	{
		private var _code:String="";
		private var _vars:MongoDocument=null;
		
		public function JavaScriptCodeScoped(code:String="", vars:MongoDocument=null) { _code = code; _vars = vars;	}

		public function get code():String {	return _code; }
		public function set code(value:String):void { _code = value; }
		public function get vars():MongoDocument { return _vars; }
		public function set vars(vars:MongoDocument):void { _vars = vars; }

		public function toString():String {	return "[JavaScriptScoped : code="+(_code == null ? "null":(_code.substr(0, 20)+"..."))+" vars="+_vars+"]"; }
	}
}