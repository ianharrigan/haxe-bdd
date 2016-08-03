package gherkin;

import gherkin.Parser.ITokenMatcher;
import gherkin.Parser.TokenType;
import gherkin.ast.Location;

class TokenMatcher implements ITokenMatcher {
    private static inline var LANGUAGE_PATTERN:String = "^\\s*#\\s*language\\s*:\\s*([a-zA-Z\\-_]+)\\s*$";
    
    private var dialectProvider(default, null):IGherkinDialectProvider;
    private var currentDialect(default, null):GherkinDialect;
    private var activeDocStringSeparator:String = null;
    private var indentToRemove:Int = 0;
    
    public static function fromDialectProvider(dialectProvider:IGherkinDialectProvider):TokenMatcher {
        return new TokenMatcher(dialectProvider);
    }
    
    public static function fromDialectName(dialectName:String):TokenMatcher {
        return new TokenMatcher(new GherkinDialectProvider(dialectName));
    }
    
    public function new(dialectProvider:IGherkinDialectProvider = null) {
        if (dialectProvider == null) {
            dialectProvider = new GherkinDialectProvider();
        }
        this.dialectProvider = dialectProvider;
        reset();
    }
    
    public function reset():Void {
        activeDocStringSeparator = null;
        indentToRemove = 0;
        currentDialect = dialectProvider.defaultDialect;
    }
    
    private function setTokenMatched(token:Token, matchedType:TokenType, text:String, keyword:String, indent:Null<Int>, items:Array<GherkinLineSpan>):Void {
        token.matchedType = matchedType;
        token.matchedKeyword = keyword;
        token.matchedText = text;
        token.matchedItems = items;
        token.matchedGherkinDialect = currentDialect;
        token.matchedIndent = indent != null ? indent : (token.line == null ? 0 : token.line.indent());
        token.location = new Location(token.location.line, token.matchedIndent + 1);
    }
    
    public function match_EOF(token:Token):Bool {
        if (token.isEOF) {
            setTokenMatched(token, TokenType.EOF, null, null, null, null);
            return true;
        }
        return false;
    }
    
    public function match_Other(token:Token):Bool {
        var text:String = token.line.getLineText(indentToRemove); //take the entire line, except removing DocString indents
        setTokenMatched(token, TokenType.Other, unescapeDocString(text), null, 0, null);
        return true;
    }
    
    public function match_Empty(token:Token):Bool {
        if (token.line.isEmpty) {
            setTokenMatched(token, TokenType.Empty, null, null, null, null);
            return true;
        }
        return false;
    }
    
    public function match_Comment(token:Token):Bool {
        if (token.line.startsWith(GherkinLanguageConstants.COMMENT_PREFIX)) {
            var text:String = token.line.getLineText(0); //take the entire line
            setTokenMatched(token, TokenType.Comment, text, null, 0, null);
            return true;
        }
        return false;
    }
    
    public function match_Language(token:Token):Bool {
        var matcher:EReg = new EReg(LANGUAGE_PATTERN, "g");
        var matches:Bool = matcher.match(token.line.getLineText(0));
        if (matches) {
            var language:String = matcher.matched(1);
            setTokenMatched(token, TokenType.Language, language, null, null, null);
            
            currentDialect = dialectProvider.getDialect(language, token.location);
            return true;
        }
        return false;
    }
    
    public function match_TagLine(token:Token):Bool {
        if (token.line.startsWith(GherkinLanguageConstants.TAG_PREFIX)) {
            setTokenMatched(token, TokenType.TagLine, null, null, null, token.line.tags);
            return true;
        }
        return false;
    }
    
    public function match_FeatureLine(token:Token):Bool {
        return matchTitleLine(token, TokenType.FeatureLine, currentDialect.featureKeywords);
    }
    
    public function match_BackgroundLine(token:Token):Bool {
        return matchTitleLine(token, TokenType.BackgroundLine, currentDialect.backgroundKeywords);
    }
    
    public function match_ScenarioLine(token:Token):Bool {
        return matchTitleLine(token, TokenType.ScenarioLine, currentDialect.scenarioKeywords);
    }
    
    public function match_ScenarioOutlineLine(token:Token):Bool {
        return matchTitleLine(token, TokenType.ScenarioOutlineLine, currentDialect.scenarioOutlineKeywords);
    }
    
    public function match_ExamplesLine(token:Token):Bool {
        return matchTitleLine(token, TokenType.ExamplesLine, currentDialect.examplesKeywords);
    }
    
    private function matchTitleLine(token:Token, tokenType:TokenType, keywords:Array<String>):Bool {
        for (keyword in keywords) {
            if (token.line.startsWithTitleKeyword(keyword)) {
                var title:String = token.line.getRestTrimmed(keyword.length + GherkinLanguageConstants.TITLE_KEYWORD_SEPARATOR.length);
                setTokenMatched(token, tokenType, title, keyword, null, null);
                return true;
            }
        }
        return false;
    }
    
    public function match_DocStringSeparator(token:Token):Bool {
        return activeDocStringSeparator == null
                // open
                ? match_DocStringSeparatorAlt(token, GherkinLanguageConstants.DOCSTRING_SEPARATOR, true) ||
                match_DocStringSeparatorAlt(token, GherkinLanguageConstants.DOCSTRING_ALTERNATIVE_SEPARATOR, true)
                // close
                : match_DocStringSeparatorAlt(token, activeDocStringSeparator, false);
    }
    
    private function match_DocStringSeparatorAlt(token:Token, separator:String, isOpen:Bool):Bool {
        if (token.line.startsWith(separator)) {
            var contentType:String = null;
            if (isOpen) {
                contentType = token.line.getRestTrimmed(separator.length);
                activeDocStringSeparator = separator;
                indentToRemove = token.line.indent();
            } else {
                activeDocStringSeparator = null;
                indentToRemove = 0;
            }
            
            setTokenMatched(token, TokenType.DocStringSeparator, contentType, null, null, null);
            return true;
        }
        return false;
    }
    
    public function match_StepLine(token:Token):Bool {
        var keywords:Array<String> = currentDialect.stepKeywords;
        for (keyword in keywords) {
            if (token.line.startsWith(keyword)) {
                var stepText:String = token.line.getRestTrimmed(keyword.length);
                setTokenMatched(token, TokenType.StepLine, stepText, keyword, null, null);
                return true;
            }
        }
        return false;
    }
    
    public function match_TableRow(token:Token):Bool {
        if (token.line.startsWith(GherkinLanguageConstants.TABLE_CELL_SEPARATOR)) {
            setTokenMatched(token, TokenType.TableRow, null, null, null, token.line.tableCells);
            return true;
        }
        return false;
    }
    
    private function unescapeDocString(text:String):String {
        //return activeDocStringSeparator != null ? text.replace("\\\"\\\"\\\"", "\"\"\"") : text;
        return activeDocStringSeparator != null ? StringTools.replace(text, "\\\"\\\"\\\"", "\"\"\"") : text;
    }
}