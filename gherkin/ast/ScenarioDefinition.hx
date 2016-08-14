package gherkin.ast;

class ScenarioDefinition extends Node {
    public var keyword(default, null):String;
    public var name(default, null):String;
    public var description(default, null):String;
    public var steps(default, null):Array<Step>;

    public function new(location:Location, keyword:String, name:String, description:String, steps:Array<Step>) {
        super(location);
        this.keyword = keyword;
        this.name = name;
        this.description = description;
        this.steps = steps;
    }

}