package gherkin.ast;

class Feature extends Node {
    public var tags(default, null):Array<Tag>;
    public var language(default, null):String;
    public var keyword(default, null):String;
    public var name(default, null):String;
    public var description(default, null):String;
    public var children(default, null):Array<ScenarioDefinition>;
    
    public function new(tags:Array<Tag>, location:Location, language:String, keyword:String, name:String, description:String, children:Array<ScenarioDefinition>) {
        super(location);
        this.tags = tags;
        this.language = language;
        this.keyword = keyword;
        this.name = name;
        this.description = description;
        this.children = children;
    }
}