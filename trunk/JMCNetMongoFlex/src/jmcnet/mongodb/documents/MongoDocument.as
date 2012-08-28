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
	
	import mx.collections.ArrayCollection;
	import mx.utils.ObjectUtil;
	
	import org.flexunit.internals.namespaces.classInternal;

	/**
	 * A generic JSON document formed by key/value pairs stored in a HashTable
	 */
	public class MongoDocument implements MongoDocumentInterface
	{
		public static var logDocument:Boolean=false; 
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoDocument);
		
		private var _table:HashTable = new HashTable();
		
		/**
		 * Construct a new MongoDocument and add the key/value pair to it.
		 * @see addKeyPairValue
		 */
		public function MongoDocument(key:String=null, value:Object=null)	{
			if (key != null)
				addKeyValuePair(key, value);
		}
		
		/**
		 * Add a key value pair to the MongoDocument object.
		 * @param key String The key used to name the value
		 * @param value Object The object to store in the MongoDocument. Any type is possible for value.
		 * @return this
		 */
		public function addKeyValuePair(key:String, value:Object):MongoDocument {
			if (logDocument) log.debug("addKeyValuePair key="+key+" value="+value);

			if (value != null && value is ArrayCollection) {
				if (logDocument) log.debug("value is ArrayCollection");
				_table.addItem(key, (value as ArrayCollection).toArray());
			}
			else {
				if (logDocument) log.debug("value is not an ArrayCollection");
				_table.addItem(key, value);
			}
			
			return this;
		}
		
		/**
		 * The static version of addKeyPairValue.
		 * see addKeyPairValue for more informations.
		 */
		public static function addKeyValuePair(key:String, value:Object):MongoDocument {
			return new MongoDocument(key, value);
		}
		
		public function getKeys():Array {
			return _table.getAllKeys();
		}
		
		/**
		 * Gets the Object which key is given or null is not found.
		 */
		public function getValue(key:String):Object {
			return _table.getItem(key);
		}
		
		public function toBSON():ByteArray {
			return BSONEncoder.encodeObjectToBSON(_table);
		}

		public function get table():HashTable {	return _table; }
		
		public function toString():String {
			var result:String = "{ ";
			var key:String;
			var value:Object;
			for (var i:int=0;i<_table.length; i++) {
				key = _table.getKeyAt(i);
				value = _table.getItem(key);
				if (i != 0) result += ", ";
				if ( value is Array) {
					result += key+": [ "+ (value != null ? value.toString():"null")+" ] ";
				}
				else  {
					result += key+":"+ (value != null ? value.toString():"null");
				}
			}
			result += "}";
			return result;
		}
		
		/**
		 * Transform a generic MongoDocument in an object which classname is given.
		 * If destClass is null, convert into generic object class (Object and ArrayCollection).
		 * @return destClass instance if given or Object if destClass is null.
		 */
		public function toObject(destClass:Class=null):* {
			log.info("Converting MongoDocument to object class :'"+destClass+"'");
			return populateObjectFromObject(this, destClass);
		}
		
		/**
		 * Populate one Object from values stored in a HashTable. If destClass is null, convert into generic object class (Object and ArrayCollection).
		 * @param destinationClass : the class of the expected object
		 */
		private function populateObjectFromObject(source:Object, destClass:Class):Object {
			if (logDocument) log.debug("Calling populateObjectFromObject source="+source+" destClass="+destClass);
			var ret:Object;
			
			if (source is String ||
				source is Number ||
				source is Date   ||
				source is Boolean ||
				source is ObjectID ||
				source == null) {
				if (logDocument) log.debug("End of populateObjectFromObject ret="+source);
				return source;
			}
			else if (source is MongoDocument) {
				ret = populateObjectFromHashTable((source as MongoDocument).table, destClass);
			}
			else if (source is HashTable) {
				ret = populateObjectFromHashTable(source as HashTable, destClass);
			}
			else if (source is Array) {
				ret = populateObjectFromArray(source as Array, destClass);
			}
			// Other objects are returned as is
			else if (source is Object) {
				ret = source;
			}
			else {
				var msgErr:String="Object type '"+getQualifiedClassName(source)+"' not implemented in MongoDocument to Object convertion.";
				log.error(msgErr);
				throw new ExceptionJMCNetMongoDB(msgErr);
			}
			
			if (logDocument) log.debug("End of populateObjectFromObject ret="+ObjectUtil.toString(ret));
			return ret;
		}
		
		/**
		 * Populate one Object from values stored in a HashTable.
		 * @param destinationClass : the class of the expected object
		 */
		private function populateObjectFromHashTable(source:HashTable, destClass:Class):Object {
			if (logDocument) log.debug("Calling populateObjectFromHashTable source="+source+" destClass="+destClass);
			var obj:Object;
			if (destClass != null) obj = new destClass();
			else obj = new Object();
			
			// looking for all attributes
			var attributes:HashTable;
			// If we are on a Object, set all attributes contained in HashTable, else set all attributes in the destClass
			if (obj is Object) {
				attributes = source;
			}
			else {
				if ( obj is MongoDocument )	{
					attributes = (obj as MongoDocument).table;
				}
				else {
					attributes = HelperClass.getObjectAttributes(obj);
				}
			}
			// valuate all attributes
			for each (var attributeName:String in attributes.getAllKeys()) {
				var item:Object = source.getItem(attributeName);
				var itemClassName:String = getQualifiedClassName(item);
				var destClassName:String = obj is MongoDocument ? "Object":HelperClass.getClassNameOfAttribute(obj,attributeName);
				if (itemClassName == "Array") {
					destClassName = HelperClass.getArrayElementTypeOfArray(obj, attributeName);
					if (destClassName == null || destClassName == "") {
						destClassName="Object";
					}
					if (logDocument) log.debug("Array element type is : "+destClassName);
				}
				if (logDocument) log.debug("Populating attribute : "+attributeName+" value="+item+" className="+itemClassName+" destClassName="+destClassName);
				if (destClass != null)	obj[attributeName] = populateObjectFromObject(item, getDefinitionByName(destClassName) as Class);
				else obj[attributeName] = populateObjectFromObject(item, null);
			}
			
			if (logDocument) log.debug("End of populateObjectFromHashTable ret="+ObjectUtil.toString(obj));
			return obj;
		}
		
		/**
		 * Populate one Array from values stored in a HashTable.
		 * @param destinationClass : the class of the expected object
		 */
		private function populateObjectFromArray(source:Array, destClass:Class):Object {
			if (logDocument) log.debug("Calling populateObjectFromArray source="+source+" destClass="+destClass);
			var obj:*;
			var value:Object;
			if (destClass != null) {
				obj = new Array();
				// store all elements in a 
				for each (value in source) {
					obj.push(populateObjectFromObject(value, destClass));
				}
			}
			else {
				obj = new ArrayCollection();
				// store all elements in a 
				for each (value in source) {
					obj.addItem(populateObjectFromObject(value, null));
				}
			}
			
			if (logDocument) log.debug("End of populateObjectFromArray obj="+ObjectUtil.toString(obj));
			return obj;
		}
		
		/**
		 * Add some classic key/value pair to help in queries
		 */
		public function gte(value:Object):MongoDocument { return addKeyValuePair("$gte", value); }
		public function gt(value:Object):MongoDocument { return addKeyValuePair("$gt", value); }
		public function lte(value:Object):MongoDocument { return addKeyValuePair("$lte", value); }
		public function lt(value:Object):MongoDocument { return addKeyValuePair("$lt", value); }
		public function ne(value:Object):MongoDocument { return addKeyValuePair("$ne", value); }
		public function exists(value:Boolean):MongoDocument { return addKeyValuePair("$exists", value); }
		
		public function all(values:Array):MongoDocument { return addKeyValuePair("$all", values); }
		public function in_(values:Array):MongoDocument { return addKeyValuePair("$in", values); }
		public function nin(values:Array):MongoDocument { return addKeyValuePair("$nin", values); }
		public function mod(modulo:int, divisor:int):MongoDocument { var a:Array = new Array(); a.push(modulo, divisor); return addKeyValuePair("$mod", a); }
		public function or(... docs:Array):MongoDocument { return addKeyValuePair("$or", docs); }
		public function nor(... docs:Array):MongoDocument { return addKeyValuePair("$nor", docs); }
		public function and(... docs:Array):MongoDocument { return addKeyValuePair("$and", docs); }
		public function size(size:uint):MongoDocument { return addKeyValuePair("$size", size); }
		/**
		 * add type criteria. You should use this constant : BSONEncoder.BSON_xxx as type
		 */
		public function type(type:uint):MongoDocument { return addKeyValuePair("$type", type);}
		public function regex(expression:String, caseInsensitive:Boolean=false, multiline:Boolean=false, extended:Boolean=false, dotAll:Boolean=false):MongoDocument {
			addKeyValuePair("$regex", expression);
			var options:String = null;
			if (caseInsensitive) options += "i";
			if (multiline) options += "m";
			if (extended) options += "x";
			if (dotAll) options += "s";
			if (options != null) addKeyValuePair("$options", options);
			return this;
		}
		public function elemMatch(value:Object):MongoDocument { return addKeyValuePair("$elemMatch", value); }
		public function not(value:Object):MongoDocument { return addKeyValuePair("$not", value); }
		
		/**
		 * Static version
		 */
		public static function gte(value:Object):MongoDocument { return new MongoDocument().gte(value); }
		public static function gt(value:Object):MongoDocument { return new MongoDocument().gt(value); }
		public static function lte(value:Object):MongoDocument { return new MongoDocument().lte(value); }
		public static function lt(value:Object):MongoDocument { return new MongoDocument().lt(value); }
		public static function ne(value:Object):MongoDocument { return new MongoDocument().ne(value); }
		public static function exists(value:Boolean):MongoDocument { return new MongoDocument().exists(value); }
		public static function all(values:Array):MongoDocument { return new MongoDocument().all(values); }
		public static function in_(values:Array):MongoDocument { return new MongoDocument().in_(values); }
		public static function nin(values:Array):MongoDocument { return new MongoDocument().nin(values); }
		public static function mod(modulo:int, result:int):MongoDocument { return new MongoDocument().mod(modulo, result); }
		public static function or(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$or", docs); }
		public static function nor(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$nor", docs); }
		public static function and(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$and", docs); }
		public static function size(size:uint):MongoDocument { return new MongoDocument().size(size); }
		public static function type(type:uint):MongoDocument { return new MongoDocument().type(type);}
		
		/**
		 * Add a regexp condition. More explanations on options can be found here : http://www.mongodb.org/display/DOCS/Advanced+Queries#AdvancedQueries-RegularExpressions
		 * @param expression (String) : the regexp expression,
		 * @param caseInsensitive (Boolean) : if true the case is insensitive. Default is false,
		 * @param multiline (Boolean) : if true, search is done on a multiline attribute. Default is false,
		 * @param extended (Boolean) : if true use the extended mode. 
		 * @param dotAll (Boolean) : if true all caracters all matched by a dot even new lines.
		 */
		public static function regex(expression:String, caseInsensitive:Boolean=false, multiline:Boolean=false, extended:Boolean=false, dotAll:Boolean=false):MongoDocument {
			return new MongoDocument().regex(expression, caseInsensitive, multiline, extended, dotAll);}
		public static function elemMatch(value:Object):MongoDocument { return new MongoDocument().elemMatch(value); }
		public static function not(value:Object):MongoDocument { return new MongoDocument().not(value); }
		
		/**
		 * New function used with aggregation (but not only with aggregagtion...)
		 */
		public function add(... docs:Array):MongoDocument { return addKeyValuePair("$add", docs); }
		public static function add(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$add", docs); }
		
		public function multiply(... docs:Array):MongoDocument { return addKeyValuePair("$multiply", docs); }
		public static function multiply(... docs:Array):MongoDocument { return new MongoDocument().addKeyValuePair("$multiply", docs); }
		
		public function divide(value1:Object, value2:Object):MongoDocument { var a:Array = new Array(); a.push(value1, value2); return addKeyValuePair("$divide", a); }
		public static function divide(value1:Object, value2:Object):MongoDocument { return new MongoDocument().divide(value1, value2); }

		public function substract(value1:Object, value2:Object):MongoDocument { var a:Array = new Array(); a.push(value1, value2); return addKeyValuePair("$substract", a); }
		public static function substract(value1:Object, value2:Object):MongoDocument { return new MongoDocument().substract(value1, value2); }
		
		public function cmp(value1:Object, value2:Object):MongoDocument { var a:Array = new Array(); a.push(value1, value2); return addKeyValuePair("$cmp", a); }
		public static function cmp(value1:Object, value2:Object):MongoDocument { return new MongoDocument().cmp(value1, value2); }
		
		public function eq(value1:Object, value2:Object):MongoDocument { var a:Array = new Array(); a.push(value1, value2); return addKeyValuePair("$eq", a); }
		public static function eq(value1:Object, value2:Object):MongoDocument { return new MongoDocument().eq(value1, value2); }
		
		/**
		 * The first expression (condition) evaluates to a Boolean value. If the first expression evaluates to true, $cond returns the value of the second expression (ifTruExpression). If the first expression evaluates to false, $cond evaluates and returns the third expression (ifFalseExpression).
		 */
		public function cond(condition:Object, ifTrueValue:Object, ifFalseValue:Object):MongoDocument { var a:Array = new Array(); a.push(condition, ifTrueValue, ifFalseValue); return addKeyValuePair("$cond", a); }
		public static function cond(condition:Object, ifTrueValue:Object, ifFalseValue:Object):MongoDocument { return new MongoDocument().cond(condition, ifTrueValue, ifFalseValue); }
		
		/**
		 * $ifNull returns the first expression if it evaluates to a non-null value. Otherwise, $ifNull returns the second expression’s value.
		 */
		public function ifNull(ifNotNullValue:Object, ifNullValue:Object):MongoDocument { var a:Array = new Array(); a.push(ifNotNullValue, ifNullValue); return addKeyValuePair("$ifNull", a); }
		public static function ifNull(ifNotNullValue:Object, ifNullValue:Object):MongoDocument { return new MongoDocument().ifNull(ifNotNullValue, ifNullValue); }
		
		/* String operations */
		public function strcasecmp(value1:String, value2:String):MongoDocument { var a:Array = new Array(); a.push(value1, value2); return addKeyValuePair("$strcasecmp", a); }
		public static function strcasecmp(value1:String, value2:String):MongoDocument { return new MongoDocument().strcasecmp(value1, value2); }
		
		public function substr(value:String, start:uint, length:uint):MongoDocument { var a:Array = new Array(); a.push(value, start, length); return addKeyValuePair("$substr", a); }
		public static function substr(value:String, start:uint, length:uint):MongoDocument { return new MongoDocument().substr(value, start, length); }
		
		public function toLower(value:String):MongoDocument { return addKeyValuePair("$toLower", value); }
		public static function toLower(value:String):MongoDocument { return new MongoDocument().toLower(value); }
		
		public function toUpper(value:String):MongoDocument { return addKeyValuePair("$toUpper", value); }
		public static function toUpper(value:String):MongoDocument { return new MongoDocument().toUpper(value); }
		
		/* date operation */
		public function dayOfYear(value:Object):MongoDocument { return addKeyValuePair("$dayOfYear", value); }
		public static function dayOfYear(value:Object):MongoDocument { return new MongoDocument().dayOfYear(value); }
		
		public function dayOfMonth(value:Object):MongoDocument { return addKeyValuePair("$dayOfMonth", value); }
		public static function dayOfMonth(value:Object):MongoDocument { return new MongoDocument().dayOfMonth(value); }
		
		public function dayOfWeek(value:Object):MongoDocument { return addKeyValuePair("$dayOfWeek", value); }
		public static function dayOfWeek(value:Object):MongoDocument { return new MongoDocument().dayOfWeek(value); }
		
		public function year(value:Object):MongoDocument { return addKeyValuePair("$year", value); }
		public static function year(value:Object):MongoDocument { return new MongoDocument().year(value); }
		
		public function month(value:Object):MongoDocument { return addKeyValuePair("$month", value); }
		public static function month(value:Object):MongoDocument { return new MongoDocument().month(value); }
		
		public function hour(value:Object):MongoDocument { return addKeyValuePair("$hour", value); }
		public static function hour(value:Object):MongoDocument { return new MongoDocument().hour(value); }
		
		public function minute(value:Object):MongoDocument { return addKeyValuePair("$minute", value); }
		public static function minute(value:Object):MongoDocument { return new MongoDocument().minute(value); }
		
		public function second(value:Object):MongoDocument { return addKeyValuePair("$second", value); }
		public static function second(value:Object):MongoDocument { return new MongoDocument().second(value); }
		
		/* Grouping functions */
		/**
		 * Returns the sum of all the values for a specified field in the grouped documents
		 */
		public function sum(value:Object):MongoDocument { return addKeyValuePair("$sum", value); }
		public static function sum(value:Object):MongoDocument { return new MongoDocument().sum(value); }
		
		/**
		 * Returns an array of all the values found in the selected field among the documents in that group.
		 * Every unique value only appears once in the result set. There is no ordering guarantee for the output documents.
		 * @see push for having multiple values int the resulting array
		 */
		public function addToSet(value:Object):MongoDocument { return addKeyValuePair("$addToSet", value); }
		public static function addToSet(value:Object):MongoDocument { return new MongoDocument().addToSet(value); }
		
		/**
		 * Returns the first value it encounters for its group.
		 */
		public function first(value:Object):MongoDocument { return addKeyValuePair("$first", value); }
		public static function first(value:Object):MongoDocument { return new MongoDocument().first(value); }
		
		/**
		 * Returns the last value it encounters for its group.
		 */
		public function last(value:Object):MongoDocument { return addKeyValuePair("$last", value); }
		public static function last(value:Object):MongoDocument { return new MongoDocument().last(value); }
		
		/**
		 * Returns the max value it encounters for its group.
		 */
		public function max(value:Object):MongoDocument { return addKeyValuePair("$max", value); }
		public static function max(value:Object):MongoDocument { return new MongoDocument().max(value); }
		
		/**
		 * Returns the min value it encounters for its group.
		 */
		public function min(value:Object):MongoDocument { return addKeyValuePair("$min", value); }
		public static function min(value:Object):MongoDocument { return new MongoDocument().min(value); }
		
		/**
		 * Returns the average value it encounters for its group.
		 */
		public function avg(value:Object):MongoDocument { return addKeyValuePair("$avg", value); }
		public static function avg(value:Object):MongoDocument { return new MongoDocument().avg(value); }
		
		/**
		 * Returns an array of all the values found in the selected field among the documents in that group.
		 * A value may appear more than once in the result set if more than one field in the grouped documents has that value.
		 * @see addToSet for having unique value in the resulting array
		 */
		public function push(value:Object):MongoDocument { return addKeyValuePair("$push", value); }
		public static function push(value:Object):MongoDocument { return new MongoDocument().push(value); }
		
		/**
		 * Returns a DBRef document. A DBRef can link a document from one collection to another document in another collection.
		 * @see http://www.mongodb.org/display/DOCS/Updating+Data+in+Mongo for more informations
		 */
		public function addDBref(key:String, collectionName:String, id:Object, databaseName:String):MongoDocument {
			return this.addKeyValuePair(key, MongoDocument.dbRef(collectionName, id, databaseName));
		}
		
		public static function dbRef(collectionName:String, id:Object, databaseName:String=null):MongoDocument {
			if (databaseName != null) {
				log.warn("DBRef using alternate Database is not supported yet by driver. collectionName="+collectionName+" id="+id+" databaseName="+databaseName);
			}
			var ret:MongoDocument = new MongoDocument("$ref", collectionName).addKeyValuePair("$id", id);
			if (databaseName != null) ret.addKeyValuePair("$db", databaseName);
			
			if (logDocument) log.debug("DBRef constructed : "+ret.toString());
			return ret;
		}
	}
}