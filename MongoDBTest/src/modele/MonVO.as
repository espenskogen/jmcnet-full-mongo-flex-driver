package modele
{
	import as3.mongo.db.document.Document;
	
	import flash.utils.getQualifiedClassName;
	
	import jmcnet.libcommun.logger.JMCNetLog4JLogger;
	
	import mx.utils.ObjectUtil;

	public class MonVO
	{
		public var champ1:String;
		public var champ2:String;
		public var champ3:String;
		public var champ4:Date;
		public var sous:Array;
		
		public function MonVO()	{}
		
		private static var log:JMCNetLog4JLogger = JMCNetLog4JLogger.getLogger(flash.utils.getQualifiedClassName(MonVO));
		
		public static function extractFromDocument(monVo:MonVO, doc:Object):MonVO	{
			log.debug("Appel extractFromDocument : vo="+ObjectUtil.toString(monVo)+" doc="+doc);
			var ci:Object = ObjectUtil.getClassInfo(monVo);
			var classname:String = ci.name;
			for each (var property:QName in ci.properties) {
				var attrName:String=property.localName;
				log.debug("On a trouvé la propriété : "+attrName+" uri="+property.uri);
				if (doc.hasOwnProperty(attrName)) {
					log.debug("La propriété : "+attrName+" est dans le doc. Elle vaut : "+doc[attrName]);
					if (doc.propertyIsEnumerable(attrName)) {
						log.debug("La propriété : "+attrName+" est un tableau");
						monVo[property.localName] = doc[attrName];
					}
					else {
						monVo[property.localName] = doc[attrName];
					}
				}
				else {
					log.debug("La propriété : "+attrName+" n'est pas dans le doc.");
				}
			}
			
			log.debug("Fin extractFromDocument : vo="+ObjectUtil.toString(monVo));
			return monVo;
		}
	}
}