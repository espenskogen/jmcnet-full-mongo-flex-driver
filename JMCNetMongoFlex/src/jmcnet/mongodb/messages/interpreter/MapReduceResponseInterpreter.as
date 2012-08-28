package jmcnet.mongodb.messages.interpreter
{
	
	
	/**
	 * This BasicResponseInterpreter is the default one. It does only transform the raw response into a simple MongoDocumentResponse
	 */
	public class MapReduceResponseInterpreter extends ComposedResponseInterpreter
	{
		public function MapReduceResponseInterpreter()	{ super("results"); }
	}
}