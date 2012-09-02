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
	public class MongoAggregationPipeline implements MongoDocumentInterface
	{
		public static var logDocument:Boolean=false; 
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoAggregationPipeline);
		
		[ArrayElementType("MongoDocument")]
		private var _tableOperator:Array = new Array();
		
		private static const PROJECT_OPERATOR:String="$project";
		private static const MATCH_OPERATOR:String="$match";
		private static const LIMIT_OPERATOR:String="$limit";
		private static const SKIP_OPERATOR:String="$skip";
		private static const UNWIND_OPERATOR:String="$unwind";
		private static const GROUP_OPERATOR:String="$group";
		private static const SORT_OPERATOR:String="$sort";
		
		public function MongoAggregationPipeline()	{ }
		
		/**
		 * Gets the array of aggregation operators
		 * @return Array of MongoDocument. Each MongoDocument contains an aggregation's operator in the order of insertion
		 */ 
		[ArrayElementType("MongoDocument")]
		public function get tabPipelineOperators():Array {
			return _tableOperator;
		}
		
		/**
		 * Adds a $project operator in the aggregation. A $project operator is used to reshape the documents.
		 * @param MongoDocument doc the document containing the $project value. Cf. http://docs.mongodb.org/manual/reference/aggregation/#_S_project
		 * @return MongoDocumentAggregationPipeline this to able to chain the operator
		 */
		public function addProjectOperator(doc:MongoDocument):MongoAggregationPipeline {
			_tableOperator.push(new MongoDocument(PROJECT_OPERATOR, doc));
			return this;
		}
		
		public static function addProjectOperator(doc:MongoDocument):MongoAggregationPipeline {
			return new MongoAggregationPipeline().addProjectOperator(doc);
		}
		
		/**
		 * Adds a $match operator in the aggregation. A $match operator is used to filter the document in the pipeline.
		 * @param MongoDocument doc the document containing the $match value. Cf. http://docs.mongodb.org/manual/reference/aggregation/#_S_match
		 * @return MongoDocumentAggregationPipeline this to able to chain the operator
		 */
		public function addMatchOperator(doc:MongoDocument):MongoAggregationPipeline {
			_tableOperator.push(new MongoDocument(MATCH_OPERATOR, doc));
			return this;
		}
		
		/**
		 * Static version of the addMatchOperator. Create a new MongoAggregationPipeline and add the $match operator.
		 * @see addMatchOperator(doc:MongoDocument)
		 * @return MongoAggregationPipeline a new pipeline with $match operator added
		 */
		public static function addMatchOperator(doc:MongoDocument):MongoAggregationPipeline {
			return new MongoAggregationPipeline().addMatchOperator(doc);
		}
		
		/**
		 * Adds a $limit operator in the aggregation. Use this to limit the result collection.
		 * @param unit nbMaxDoc the maximum number of document returned. Cf. http://docs.mongodb.org/manual/reference/aggregation/#_S_limit
		 * @return MongoDocumentAggregationPipeline this to able to chain the operator
		 */
		public function addLimitOperator(nbMaxDoc:uint):MongoAggregationPipeline {
			_tableOperator.push(new MongoDocument(LIMIT_OPERATOR, nbMaxDoc));
			return this;
		}
		
		/**
		 * Static version of the addLimitOperator. Create a new MongoAggregationPipeline and add the $limit operator.
		 * @see addLimitOperator(doc:MongoDocument)
		 * @return MongoAggregationPipeline a new pipeline with $limit operator added
		 */
		public static function addLimitOperator(nbMaxDoc:uint):MongoAggregationPipeline {
			return new MongoAggregationPipeline().addLimitOperator(nbMaxDoc);
		}
		
		/**
		 * Adds a $skip operator in the aggregation. Use this to skip the result collection.
		 * @param unit nbDocToSkip the maximum number of document returned. Cf. http://docs.mongodb.org/manual/reference/aggregation/#_S_skip
		 * @return MongoDocumentAggregationPipeline this to able to chain the operator
		 */
		public function addSkipOperator(nbDocToSkip:uint):MongoAggregationPipeline {
			_tableOperator.push(new MongoDocument(SKIP_OPERATOR, nbDocToSkip));
			return this;
		}
		
		/**
		 * Static version of the addSkipOperator. Create a new MongoAggregationPipeline and add the $skip operator.
		 * @see addSkipOperator(doc:MongoDocument)
		 * @return MongoAggregationPipeline a new pipeline with $skip operator added
		 */
		public static function addSkipOperator(nbDocToSkip:uint):MongoAggregationPipeline {
			return new MongoAggregationPipeline().addSkipOperator(nbDocToSkip);
		}
		
		/**
		 * Adds a $unwind operator in the aggregation. Use this to peels off the elements of an array individually, and returns a stream of documents.
		 * @param String attributeName. The attribute name that will be peeled off. If the attribute don't begins with a '$' then this method adds it automatically. Cf. http://docs.mongodb.org/manual/reference/aggregation/#_S_unwind
		 * @return MongoDocumentAggregationPipeline this to able to chain the operator
		 */
		public function addUnwindOperator(attributeName:String):MongoAggregationPipeline {
			var a:String = attributeName;
			if (attributeName.charAt(0) != "$") a = "$"+a;
			_tableOperator.push(new MongoDocument(UNWIND_OPERATOR, a));
			return this;
		}
		
		/**
		 * Static version of the addUnwindOperator. Create a new MongoAggregationPipeline and add the $unwind operator.
		 * @see addUnwindOperator(doc:MongoDocument)
		 * @return MongoAggregationPipeline a new pipeline with $unwind operator added
		 */
		public static function addUnwindOperator(attributeName:String):MongoAggregationPipeline {
			return new MongoAggregationPipeline().addUnwindOperator(attributeName);
		}
		
		/**
		 * Adds a $group operator in the aggregation. A $group operator is used for the purpose of calculating aggregate values based on a collection of documents.
		 * @param MongoDocument doc the document containing the $group value. Cf. http://docs.mongodb.org/manual/reference/aggregation/#_S_group
		 * @return MongoDocumentAggregationPipeline this to able to chain the operator
		 */
		public function addGroupOperator(doc:MongoDocument):MongoAggregationPipeline {
			_tableOperator.push(new MongoDocument(GROUP_OPERATOR, doc));
			return this;
		}
		
		/**
		 * Static version of the addGroupOperator. Create a new MongoAggregationPipeline and add the $group operator.
		 * @see addGroupOperator(doc:MongoDocument)
		 * @return MongoAggregationPipeline a new pipeline with $group operator added
		 */
		public static function addGroupOperator(doc:MongoDocument):MongoAggregationPipeline {
			return new MongoAggregationPipeline().addGroupOperator(doc);
		}
		
		/**
		 * Adds a $sort operator in the aggregation. The $sort pipeline operator sorts all input documents and returns them to the pipeline in sorted order.
		 * @param MongoDocument doc the document containing the $sort value. Cf. http://docs.mongodb.org/manual/reference/aggregation/#_S_sort
		 * @return MongoDocumentAggregationPipeline this to able to chain the operator
		 */
		public function addSortOperator(doc:MongoDocument):MongoAggregationPipeline {
			_tableOperator.push(new MongoDocument(SORT_OPERATOR, doc));
			return this;
		}
		
		/**
		 * Static version of the addSortOperator. Create a new MongoAggregationPipeline and add the $sort operator.
		 * @see addSortOperator(doc:MongoDocument)
		 * @return MongoAggregationPipeline a new pipeline with $sort operator added
		 */
		public static function addSortOperator(doc:MongoDocument):MongoAggregationPipeline {
			return new MongoAggregationPipeline().addSortOperator(doc);
		}
				
	}
}