package jmcnet.mongodb.errors
{
	import jmcnet.libcommun.communs.exceptions.ExceptionTechnique;
	
	public class ExceptionJMCNetMongoDB extends ExceptionTechnique
	{
		public function ExceptionJMCNetMongoDB(message:String="", id:int=0)
		{
			super(message, id);
		}
	}
}