package gherkin.ast;

class ScenarioOutline extends ScenarioDefinition {
    public var tags(default, null):Array<Tag>;
    public var examples(default, null):Array<Examples>;
    
    public function new(tags:Array<Tag>, location:Location, keyword:String, name:String, description:String, steps:Array<Step>, examples:Array<Examples>) {
        super(location, keyword, name, description, steps);
        this.tags = tags;
        this.examples = examples;
    }
}