package gherkin.ast;

class DocString extends Node {
    public var contentType(default, null):String;
    public var content(default, null):String;

    public function new(location:Location, contentType:String, content:String) {
        super(location);
        this.contentType = contentType;
        this.content = content;
    }
}