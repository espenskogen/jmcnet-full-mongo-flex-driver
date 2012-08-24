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

	/**
	 * A generic JSON document formed by key/value pairs stored in a HashTable
	 */
	public class MongoDocument implements MongoDocumentInterface
	{
		public static var logDocument:Boolean=false; 
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(MongoDocument);
		
		private var _table:HashTable = new HashTable();
		
		public function MongoDocument(key:String=null, value:Object=null)	{
			if (key != null)
				addKeyValuePair(key, value);
		}
		
		/**
		 * Add a key value pair to the MongoDocument object.
		 * @param key String The key used to name the value
		 * @param value Object The object to store in the MongoDocument. Type possible for value is Number, String, Date, Boolean, MongoDocumentInterface, Array or ArrayCollection. 
		 * @return this
		 */
		public function addKeyValuePair(key:String, value:Object):MongoDocument {
			if (logDocument) log.debug("addKeyValuePair key="+key+" value="+value);
//			if (value != null) {
//				// value can only be String, Number, Boolean, uint, int or Date
//				if (! (value is Number) &&
//					! (value is String) &&
//					! (value is Date) &&
//					! (value is Boolean) &&
//					! (value is MongoDocumentInterface) &&
//					! (value is Array) &&
//					! (value is ArrayCollection)) {
//					var errMsg:String="document value can only be one of Number, String, Date, Boolean, MongoDocumentInterface, Array or ArrayCollection";
//					log.error(errMsg);
//					throw new ExceptionJMCNetMongoDB(errMsg);
//				}
//			}
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
		 * Transform a generic MongoDocument in an object which classname is given
		 */
		public function toObject(destClass:Class):* {
			log.info("Converting MongoDocument to object class :'"+destClass);
			return populateObjectFromObject(this, destClass);
		}
		
		/**
		 * Populate one Object from values stored in a HashTable.
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
			var obj:Object = new destClass();
			// looking for all attributes
			var attributes:HashTable;
			// If we are on a Object, set all attributes contained in HashTable, else set all attributes in the destClass
			if (destClass == Object) {
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
				obj[attributeName] = populateObjectFromObject(item, getDefinitionByName(destClassName) as Class);
			}
			
			if (logDocument) log.debug("End of populateObjectFromHashTable ret="+ObjectUtil.toString(obj));
			return obj;
		}
		
		/**
		 * Populate one Array from values stored in a HashTable.
		 * @param destinationClass : the class of the expected object
		 */
		private function populateObjectFromArray(source:Array, destClass:Class):Object {
			if (logDocument) log.debug("Calling populateObjectFromArray source="+source);
			var obj:Array = new Array();
			// store all elements in a 
			for each (var value:Object in source) {
				obj.push(populateObjectFromObject(value, destClass));
			}
			
			if (logDocument) log.debug("End of populateObjectFromArray");
			return obj;
		}
		
		/**
		 * Transform a genreic MongoDocument in an generic object composed uniquely of ArrayCollection and Object
		 * @return an Object containing ArrayCollection for arrays or Object or any combinsaison of the both
		 */
		public function toGenericObject():Object {
			log.info("Converting MongoDocument to generic object composed of ArrayCollection and Object");
			return populateGenericObjectFromObject(this);
		}
		
		/**
		 * Populate one Object from values stored in a HashTable.
		 * @return an ArrayCollection for arrays or Object or any combinaison of both
		 */
		private function populateGenericObjectFromObject(source:Object):Object {
			if (logDocument) log.debug("Calling populateObjectFromGenericObject source="+source);
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
				ret = populateGenericObjectFromHashTable((source as MongoDocument).table);
			}
			else if (source is HashTable) {
				ret = populateGenericObjectFromHashTable(source as HashTable);
			}
			else if (source is Array) {
				ret = populateGenericObjectFromArray(source as Array);
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
		private function populateGenericObjectFromHashTable(source:HashTable):Object {
			if (logDocument) log.debug("Calling populateGenericObjectFromHashTable source="+source);
			var obj:Object = new Object();
			// looking for all attributes
			var attributes:HashTable = source;
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
				obj[attributeName] = populateGenericObjectFromObject(item);
			}
			
			if (logDocument) log.debug("End of populateObjectFromHashTable ret="+ObjectUtil.toString(obj));
			return obj;
		}
		
		/**
		 * Populate one Array from values stored in a HashTable.
		 * @param destinationClass : the class of the expected object
		 */
		private function populateGenericObjectFromArray(source:Array):Object {
			if (logDocument) log.debug("Calling populateGenericObjectFromArray source="+source);
			var obj:ArrayCollection = new ArrayCollection();
			// store all elements in a 
			for each (var value:Object in source) {
				obj.addItem(populateGenericObjectFromObject(value));
			}
			
			if (logDocument) log.debug("End of populateGenericObjectFromArray");
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
		public function mod(modulo:int, result:int):MongoDocument { return addKeyValuePair("$mod", new Array(modulo, result)); }
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
		
	}
}