package gherkin;

class GherkinLineSpan {
    // One-based line position
    public var column(default, null):Int;
    
    // text part of the line
    public var text(default, null):String;
    
    public function new(column:Int, text:String) {
        this.column = column;
        this.text = text;
    }
    
    public function equals(o:GherkinLineSpan):Bool {
        if (this == o) return true;
        if (o == null) return false;
        return column == o.column && text == o.text;
    }
}