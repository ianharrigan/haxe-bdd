package gherkin;

class GherkinDialect {
    public var language(default, null):String;
    private var _keywords:Map<String, Array<String>>;
    
    public function new(language:String, keywords:Map<String, Array<String>>) {
        this.language = language;
        this._keywords = keywords;
    }
    
    public var featureKeywords(get, null):Array<String>;
    private function get_featureKeywords():Array<String> {
        return _keywords.get("feature");
    }
    
    public var scenarioKeywords(get, null):Array<String>;
    private function get_scenarioKeywords():Array<String> {
        return _keywords.get("scenario");
    }
    
    public var stepKeywords(get, null):Array<String>;
    private function get_stepKeywords():Array<String> {
        var result:Array<String> = new Array<String>();
        result = result.concat(_keywords.get("given"));
        result = result.concat(_keywords.get("when"));
        result = result.concat(_keywords.get("then"));
        result = result.concat(_keywords.get("and"));
        result = result.concat(_keywords.get("but"));
        return result;
    }
    
    public var backgroundKeywords(get, null):Array<String>;
    private function get_backgroundKeywords():Array<String> {
        return _keywords.get("background");
    }
    
    public var scenarioOutlineKeywords(get, null):Array<String>;
    private function get_scenarioOutlineKeywords():Array<String> {
        return _keywords.get("scenarioOutline");
    }
    
    public var examplesKeywords(get, null):Array<String>;
    private function get_examplesKeywords():Array<String> {
        return _keywords.get("examples");
    }
}