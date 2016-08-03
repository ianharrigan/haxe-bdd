package gherkin.ast;

class Location {
    public var line(default, null):Int;
    public var column(default, null):Int;
    
    public function new(line:Int, column:Int) {
        this.line = line;
        this.column = column;
    }
}