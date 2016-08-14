package gherkin.ast;

class TableCell extends Node {
    public var value(default, default):String;

    public function new(location:Location, value:String) {
        super(location);
        this.value = value;
    }
}