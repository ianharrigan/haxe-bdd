package gherkin.ast;

class Background extends ScenarioDefinition {
    public function new(location:Location, keyword:String, name:String, description:String, steps:Array<Step>) {
        super(location, keyword, name, description, steps);
    }
}