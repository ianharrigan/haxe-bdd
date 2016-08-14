package gherkin.ast;

class Step extends Node {
    public var keyword(default, null):String;
    public var text(default, null):String;
    public var argument(default, null):Node;

    public function new(location:Location, keyword:String, text:String, argument:Node) {
        super(location);
        this.keyword = keyword;
        this.text = text;
        this.argument = argument;
    }
}