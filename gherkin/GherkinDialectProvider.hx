package gherkin;
import gherkin.ast.Location;

class GherkinDialectProvider implements IGherkinDialectProvider {
    private static var DIALECTS:Map<String, Map<String, Array<String>>>;
    
    private var _defaultDialectName:String;
    
    public function new(defaultDialectName:String = "en") {
        initDialects();
        _defaultDialectName = defaultDialectName;
    }
    
    private static function initDialects() {
        if (DIALECTS != null) {
            return;
        }
        
        DIALECTS = new Map<String, Map<String, Array<String>>>();
        
        // only support "en" for now - should probably read this from json as gherkin-java does
        var data:Map<String, Array<String>> = new Map<String, Array<String>>();
        data.set("and", ["* ", "And "]);
        data.set("background", ["Background"]);
        data.set("but", ["* ", "But "]);
        data.set("examples", ["Examples", "Scenarios"]);
        data.set("feature", ["Feature", "Business Need", "Ability"]);
        data.set("given", ["* ", "Given "]);
        data.set("scenario", ["Scenario"]);
        data.set("scenarioOutline", ["Scenario Outline", "Scenario Template"]);
        data.set("then", ["* ", "Then "]);
        data.set("when", ["* ", "When "]);
        
        DIALECTS.set("en", data);
    }
    
    public var defaultDialect(get, null):GherkinDialect;
    private function get_defaultDialect():GherkinDialect {
        return getDialect(_defaultDialectName, null);
    }

    public function getDialect(language:String, location:Location):GherkinDialect {
        var map:Map<String, Array<String>> = DIALECTS.get(language);
        if (map == null) {
            throw new ParserException.NoSuchLanguageException(language, location);
        }
        return new GherkinDialect(language, map);
    }
}