package gherkin.ast;

class Scenario extends ScenarioDefinition {
    public var tags(default, default):Array<Tag>;
    
    public function new(tags:Array<Tag>, location:Location, keyword:String, name:String, description:String, steps:Array<Step>) {
        super(location, keyword, name, description, steps);
        this.tags = tags;
    }
    
    public function addTag(tag:Tag) {
        if (tags == null) {
            tags = new Array<Tag>();
        }
        var found:Bool = false;
        for (t in tags) {
            if (t.name == tag.name) {
                found = true;
                break;
            }
        }
        if (found == false) {
            tags.push(tag);
        }
    }
    
    public function addTags(tags:Array<Tag>) {
        if (tags == null) {
            return;
        }
        for (t in tags) {
            addTag(t);
        }
    }
}