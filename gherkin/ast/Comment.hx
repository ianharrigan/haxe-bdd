package gherkin.ast;

class Comment extends Node {
    public var text(default, null):String;
    
    public function new(location:Location, text:String) {
        super(location);
        this.text = text;
    }
}