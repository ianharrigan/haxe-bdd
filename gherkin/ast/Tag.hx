package gherkin.ast;

class Tag extends Node {
    public var name(default, null):String;
    
    public function new(location:Location, name:String) {
        super(location);
        this.name = name;
    }
    
}