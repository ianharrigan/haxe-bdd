package gherkin;

import gherkin.Parser.TokenType;
import gherkin.ast.Location;

class Token {
    public var line(default, null):IGherkinLine;
    public var matchedType(default, default):TokenType;
    public var matchedKeyword(default, default):String;
    public var matchedText(default, default):String;
    public var matchedItems(default, default):Array<GherkinLineSpan>;
    public var matchedIndent(default, default):Int;
    public var matchedGherkinDialect(default, default):GherkinDialect;
    public var location(default, default):Location;

    public function new(line:IGherkinLine, location:Location) {
        this.line = line;
        this.location = location;
    }

    public var isEOF(get, null):Bool;
    private function get_isEOF():Bool {
        return line == null;
    }

    public function detach():Void {
        if (line != null) {
            line.detach();
        }
    }

    public var tokenValue(get, null):String;
    private function get_tokenValue():String {
        return isEOF ? "EOF" : line.getLineText(-1);
    }

    public function toString():String {
        return '${matchedType}: ${matchedKeyword} ${matchedText}';
    }
}