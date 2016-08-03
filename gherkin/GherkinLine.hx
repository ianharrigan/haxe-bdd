package gherkin;

class GherkinLine implements IGherkinLine {
    private var lineText(default, null):String;
    private var trimmedLineText(default, null):String;
    
    public function new(lineText:String) {
        this.lineText = lineText;
        this.trimmedLineText = StringTools.ltrim(lineText);
    }
    
    public function indent():Int {
        return countSymbols(lineText) - countSymbols(trimmedLineText);
    }
    
    private function countSymbols(s:String) {
        return s.length;
    }
    
    public function detach():Void {
        
    }
    
    public function getLineText(indentToRemove:Int):String {
        if (indentToRemove < 0 || indentToRemove > indent())
            return trimmedLineText;
        return lineText.substring(indentToRemove);    
    }
    
    public var isEmpty(get, null):Bool;
    private function get_isEmpty():Bool {
        return trimmedLineText.length == 0;
    }
    
    public function startsWith(prefix:String):Bool {
        return StringTools.startsWith(trimmedLineText, prefix);
    }
    
    public function getRestTrimmed(length:Int):String {
        return StringTools.trim(trimmedLineText.substring(length));
    }
    
    public var tags(get, null):Array<GherkinLineSpan>;
    private function get_tags():Array<GherkinLineSpan> {
        return getSpans("\\s+");
    }
    
    public function startsWithTitleKeyword(text:String):Bool {
        var textLength:Int = text.length;
        return trimmedLineText.length > textLength &&
                StringTools.startsWith(trimmedLineText, text) &&
                trimmedLineText.substring(textLength, textLength + GherkinLanguageConstants.TITLE_KEYWORD_SEPARATOR.length)
                    == GherkinLanguageConstants.TITLE_KEYWORD_SEPARATOR;
        // TODO aslak: extract startsWithFrom method for clarity
    }
    
    public var tableCells(get, null):Array<GherkinLineSpan>;
    private function get_tableCells():Array<GherkinLineSpan> {
        var lineSpans:Array<GherkinLineSpan> = new Array<GherkinLineSpan>();
        var cell:StringBuf = new StringBuf();
        var beforeFirst:Bool = true;
        var startCol:Int = 0;
        //for (col in 0...trimmedLineText.length) {
        var col:Int = 0;
        while (col < trimmedLineText.length) {
            var c:String = trimmedLineText.charAt(col);
            if (c == '|') {
                if (beforeFirst) {
                    // Skip the first empty span
                    beforeFirst = false;
                } else {
                    var contentStart = 0;
                    while (contentStart < cell.length && Character.isWhitespace(cell.toString().charAt(contentStart))) {
                        contentStart++;
                    }
                    if (contentStart == cell.length) {
                        contentStart = 0;
                    }
                    lineSpans.push(new GherkinLineSpan(indent() + startCol + contentStart + 2, StringTools.trim(cell.toString())));
                    startCol = col;
                }
                cell = new StringBuf();
            } else if (c == '\\') {
                col++;
                c = trimmedLineText.charAt(col);
                if (c == 'n') {
                    cell.add('\n');
                } else {
                    if (c != '|' && c != '\\') {
                        cell.add('\\');
                    }
                    cell.add(c);
                }
            } else {
                cell.add(c);
            }
            col++;
        }
        
        return lineSpans;
    }
    
    public function getSpans(delimiter:String):Array<GherkinLineSpan> {
        var matcher:EReg = new EReg(delimiter, "g");
        var lineSpans:Array<GherkinLineSpan> = new Array<GherkinLineSpan>();
        var arr:Array<String> = matcher.split(trimmedLineText);
        var column:Int = 0;
        for (cell in arr) {
            if (StringTools.trim(cell) == "") {
                continue;
            }
            var n:Int = trimmedLineText.indexOf(cell);
            column = n + indent() + 1;
            lineSpans.push(new GherkinLineSpan(column, cell));
        }
        return lineSpans;
    }
}