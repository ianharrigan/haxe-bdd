package gherkin;

interface IGherkinLine {
    public function indent():Int;

    public function detach():Void;

    public function getLineText(indentToRemove:Int):String;

    public var isEmpty(get, null):Bool;

    public function startsWith(prefix:String):Bool;

    public function getRestTrimmed(length:Int):String;

    public var tags(get, null):Array<GherkinLineSpan>;

    public function startsWithTitleKeyword(keyword:String):Bool;

    public var tableCells(get, null):Array<GherkinLineSpan>;
}