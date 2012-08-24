package jmcnet.mongodb.documents
{
	import flash.utils.ByteArray;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	
	import jmcnet.libcommun.communs.helpers.HelperClass;
	import jmcnet.libcommun.communs.structures.HashTable;
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	import jmcnet.mongodb.bson.BSONEncoder;
	import jmcnet.mongodb.errors.ExceptionJMCNetMongoDB;
	
	import mx.utils.ObjectUtil;

	/**
	 * A generic JSON document formed by key/value pairs stored in a HashTable
	 */
	public class MongoDocumentAggregationPipeline extends MongoDocument
	{
		public static var logDocument:Boolean=false; 
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoDocumentAggregationPipeline);
		
		private var _table:HashTable = new HashTable();
		
		public function MongoDocumentAggregationPipeline()	{ }
		
		public function addProject():MongoDocumentAggregationPipeline {
			return this;
		}		
		
		/**
		 * Add some classic key/value pair to help in queries
		 */
//		public function gte(value:Object):MongoDocument { return addKeyValuePair("$gte", value); }
//		public function gt(value:Object):MongoDocument { return addKeyValuePair("$gt", value); }
//		public function lte(value:Object):MongoDocument { return addKeyValuePair("$lte", value); }
//		public function lt(value:Object):MongoDocument { return addKeyValuePair("$lt", value); }
//		public function ne(value:Object):MongoDocument { return addKeyValuePair("$ne", value); }
//		public function exists(value:Boolean):MongoDocument { return addKeyValuePair("$exists", value); }
//		
//		public function all(values:Array):MongoDocument { return addKeyValuePair("$all", values); }
//		public function in_(values:Array):MongoDocument { return addKeyValuePair("$in", values); }
//		public function nin(values:Array):MongoDocument { return addKeyValuePair("$nin", values); }
//		public function mod(modulo:int, result:int):MongoDocument { return addKeyValuePair("$mod", new Array(modulo, result)); }
//		public function or(... docs:Array):MongoDocument { return addKeyValuePair("$or", docs); }
//		public function nor(... docs:Array):MongoDocument { return addKeyValuePair("$nor", docs); }
//		public function and(... docs:Array):MongoDocument { return addKeyValuePair("$and", docs); }
//		public function size(size:uint):MongoDocument { return addKeyValuePair("$size", size); }
		/**
		 * add type criteria. You should use this constant : BSONEncoder.BSON_xxx as type
		 */
//		public function type(type:uint):MongoDocument { return addKeyValuePair("$type", type);}
//		public function regex(expression:String, caseInsensitive:Boolean=false, multiline:Boolean=false, extended:Boolean=false, dotAll:Boolean=false):MongoDocument {
//			addKeyValuePair("$regex", expression);
//			var options:String = null;
//			if (caseInsensitive) options += "i";
//			if (multiline) options += "m";
//			if (extended) options += "x";
//			if (dotAll) options += "s";
//			if (options != null) addKeyValuePair("$options", options);
//			return this;
//		}
//		public function elemMatch(value:Object):MongoDocument { return addKeyValuePair("$elemMatch", value); }
//		public function not(value:Object):MongoDocument { return addKeyValuePair("$not", value); }
		
		/**
		 * Static version
		 */
//		public static function gte(value:Object):MongoDocument { return new MongoDocument().gte(value); }
//		public static function gt(value:Object):MongoDocument { return new MongoDocument().gt(value); }
//		public static function lte(value:Object):MongoDocument { return new MongoDocument().lte(value); }
//		public static function lt(value:Object):MongoDocument { return new MongoDocument().lt(value); }
//		public static function ne(value:Object):MongoDocument { return new MongoDocument().ne(value); }
//		public static function exists(value:Boolean):MongoDocument { return new MongoDocument().exists(value); }
//		public static function all(values:Array):MongoDocument { return new MongoDocument().all(values); }
//		public static function in_(values:Array):MongoDocument { return new MongoDocument().in_(values); }
//		public static function nin(values:Array):MongoDocument { return new MongoDocument().nin(values); }
//		public static function mod(modulo:int, result:int):MongoDocument { return new MongoDocument().mod(modulo, result); }
//		public static function or(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$or", docs); }
//		public static function nor(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$nor", docs); }
//		public static function and(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$and", docs); }
//		public static function size(size:uint):MongoDocument { return new MongoDocument().size(size); }
//		public static function type(type:uint):MongoDocument { return new MongoDocument().type(type);}
		
		/**
		 * Add a regexp condition. More explanations on options can be found here : http://www.mongodb.org/display/DOCS/Advanced+Queries#AdvancedQueries-RegularExpressions
		 * @param expression (String) : the regexp expression,
		 * @param caseInsensitive (Boolean) : if true the case is insensitive. Default is false,
		 * @param multiline (Boolean) : if true, search is done on a multiline attribute. Default is false,
		 * @param extended (Boolean) : if true use the extended mode. 
		 * @param dotAll (Boolean) : if true all caracters all matched by a dot even new lines.
		 */
//		public static function regex(expression:String, caseInsensitive:Boolean=false, multiline:Boolean=false, extended:Boolean=false, dotAll:Boolean=false):MongoDocument {
//			return new MongoDocument().regex(expression, caseInsensitive, multiline, extended, dotAll);}
//		public static function elemMatch(value:Object):MongoDocument { return new MongoDocument().elemMatch(value); }
//		public static function not(value:Object):MongoDocument { return new MongoDocument().not(value); }
		
	}
}