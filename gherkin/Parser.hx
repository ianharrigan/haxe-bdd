package gherkin;
import gherkin.Parser.ParserContext;
import haxe.macro.Context;

enum TokenType {
    None;
    EOF;
    Empty;
    Comment;
    TagLine;
    FeatureLine;
    BackgroundLine;
    ScenarioLine;
    ScenarioOutlineLine;
    ExamplesLine;
    StepLine;
    DocStringSeparator;
    TableRow;
    Language;
    Other;
}

enum RuleType {
    None;
    _EOF; // #EOF
    _Empty; // #Empty
    _Comment; // #Comment
    _TagLine; // #TagLine
    _FeatureLine; // #FeatureLine
    _BackgroundLine; // #BackgroundLine
    _ScenarioLine; // #ScenarioLine
    _ScenarioOutlineLine; // #ScenarioOutlineLine
    _ExamplesLine; // #ExamplesLine
    _StepLine; // #StepLine
    _DocStringSeparator; // #DocStringSeparator
    _TableRow; // #TableRow
    _Language; // #Language
    _Other; // #Other
    GherkinDocument; // GherkinDocument! := Feature?
    Feature; // Feature! := Feature_Header Background? Scenario_Definition*
    Feature_Header; // Feature_Header! := #Language? Tags? #FeatureLine Feature_Description
    Background; // Background! := #BackgroundLine Background_Description Scenario_Step*
    Scenario_Definition; // Scenario_Definition! := Tags? (Scenario | ScenarioOutline)
    Scenario; // Scenario! := #ScenarioLine Scenario_Description Scenario_Step*
    ScenarioOutline; // ScenarioOutline! := #ScenarioOutlineLine ScenarioOutline_Description ScenarioOutline_Step* Examples_Definition*
    Examples_Definition; // Examples_Definition! [#Empty|#Comment|#TagLine-&gt;#ExamplesLine] := Tags? Examples
    Examples; // Examples! := #ExamplesLine Examples_Description Examples_Table?
    Examples_Table; // Examples_Table! := #TableRow #TableRow*
    Scenario_Step; // Scenario_Step := Step
    ScenarioOutline_Step; // ScenarioOutline_Step := Step
    Step; // Step! := #StepLine Step_Arg?
    Step_Arg; // Step_Arg := (DataTable | DocString)
    DataTable; // DataTable! := #TableRow+
    DocString; // DocString! := #DocStringSeparator #Other* #DocStringSeparator
    Tags; // Tags! := #TagLine+
    Feature_Description; // Feature_Description := Description_Helper
    Background_Description; // Background_Description := Description_Helper
    Scenario_Description; // Scenario_Description := Description_Helper
    ScenarioOutline_Description; // ScenarioOutline_Description := Description_Helper
    Examples_Description; // Examples_Description := Description_Helper
    Description_Helper; // Description_Helper := #Empty* Description? #Comment*
    Description; // Description! := #Other+
}

class RuleTypeConverter {
    public static function convert(tokenType:TokenType):RuleType {
        return RuleType.createByIndex(tokenType.getIndex());
    }
}

class ParserContext {
    public var tokenScanner(default, null):ITokenScanner;
    public var tokenMatcher(default, null):ITokenMatcher;
    public var tokenQueue(default, default):Array<Token>;
    public var errors(default, null):Array<ParserException>;

    public function new(tokenScanner:ITokenScanner, tokenMatcher:ITokenMatcher, tokenQueue:Array<Token>, errors:Array<ParserException>) {
        this.tokenScanner = tokenScanner;
        this.tokenMatcher = tokenMatcher;
        this.tokenQueue = tokenQueue;
        this.errors = errors;
    }
}

class Parser<T> {
    private var builder:Builder<T>;
    public var stopAtFirstError:Bool;
    
    public function new(builder:Builder<T>) {
        this.builder = builder;
    }

    public function parseString(s:String, tokenMatcher:ITokenMatcher = null):T {
        if (tokenMatcher == null) {
            tokenMatcher = new TokenMatcher();
        }
        var tokenScanner:ITokenScanner = new TokenScanner(s);
        return parse(tokenScanner, tokenMatcher);
    }
    
    public function parse(tokenScanner:ITokenScanner, tokenMatcher:ITokenMatcher):T {
        builder.reset();
        tokenMatcher.reset();
        
        var context:ParserContext = new ParserContext(
                tokenScanner,
                tokenMatcher,
                new Array<Token>(),
                new Array<ParserException>()
        );
        
        startRule(context, RuleType.GherkinDocument);
        var state = 0;
        var token:Token = null;
        do {
            token = readToken(context);
            state = matchToken(state, token, context);
        } while (!token.isEOF);
        
        endRule(context, RuleType.GherkinDocument);
        
        if (context.errors.length > 0) {
            throw new ParserException.CompositeParserException(context.errors);
        }
        return builder.result;
    }
    
    private function addError(context:ParserContext, error:ParserException):Void {
        context.errors.push(error);
        if (context.errors.length > 10)
            throw new ParserException.CompositeParserException(context.errors);
    }
    
    private function handleAstError<V>(context:ParserContext, action:Void->V):V {
        return handleExternalError(context, action, null);
    }
    
    private function handleExternalError<V>(context:ParserContext, action:Void->V, defaultValue:V):V {
        if (stopAtFirstError) {
            return action();
        }
        
        try {
            return action();
        } catch (compositeParserException:ParserException.CompositeParserException) {
            for (error in compositeParserException.errors) {
                addError(context, error);
            }
        } catch (error:ParserException) {
            addError(context, error);
        }
        
        return defaultValue;
    }
    
    private function build(context:ParserContext, token:Token):Void {
        handleAstError(context, function() {
            builder.build(token);
            return null;
        });
    }
    
    private function startRule(context:ParserContext, ruleType:RuleType):Void {
        handleAstError(context, function() {
            builder.startRule(ruleType);
            return null;
        });
    }
    
    private function endRule(context:ParserContext, ruleType:RuleType):Void {
        handleAstError(context, function() {
            builder.endRule(ruleType);
            return null;
        });
    }
    
    private function readToken(context:ParserContext):Token {
        return context.tokenQueue.length > 0 ? context.tokenQueue.pop() : context.tokenScanner.read();
    }
    
    private function match_EOF(context:ParserContext, token:Token):Bool {
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_EOF(token);
        }, false);
    }
    
    private function match_Empty(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_Empty(token);
        }, false);
    }
    
    private function match_Comment(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_Comment(token);
        }, false);
    }
    
    private function match_TagLine(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_TagLine(token);
        }, false);
    }
    
    private function match_FeatureLine(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_FeatureLine(token);
        }, false);
    }
    
    private function match_BackgroundLine(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_BackgroundLine(token);
        }, false);
    }
    
    private function match_ScenarioLine(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_ScenarioLine(token);
        }, false);
    }
    
    private function match_ScenarioOutlineLine(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_ScenarioOutlineLine(token);
        }, false);
    }
    
    private function match_ExamplesLine(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_ExamplesLine(token);
        }, false);
    }
    
    private function match_StepLine(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_StepLine(token);
        }, false);
    }
    
    private function match_DocStringSeparator(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_DocStringSeparator(token);
        }, false);
    }
    
    private function match_TableRow(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_TableRow(token);
        }, false);
    }
    
    private function match_Language(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_Language(token);
        }, false);
    }
    
    private function match_Other(context:ParserContext, token:Token):Bool {
        if (token.isEOF) return false;
        return handleExternalError(context, function() {
            return context.tokenMatcher.match_Other(token);
        }, false);
    }
    
    private function matchToken(state:Int, token:Token, context:ParserContext):Int {
        var newState:Int = -1;
        switch (state) {
            case 0:
                newState = matchTokenAt_0(token, context);
            case 1:
                newState = matchTokenAt_1(token, context);
            case 2:
                newState = matchTokenAt_2(token, context);
            case 3:
                newState = matchTokenAt_3(token, context);
            case 4:
                newState = matchTokenAt_4(token, context);
            case 5:
                newState = matchTokenAt_5(token, context);
            case 6:
                newState = matchTokenAt_6(token, context);
            case 7:
                newState = matchTokenAt_7(token, context);
            case 8:
                newState = matchTokenAt_8(token, context);
            case 9:
                newState = matchTokenAt_9(token, context);
            case 10:
                newState = matchTokenAt_10(token, context);
            case 11:
                newState = matchTokenAt_11(token, context);
            case 12:
                newState = matchTokenAt_12(token, context);
            case 13:
                newState = matchTokenAt_13(token, context);
            case 14:
                newState = matchTokenAt_14(token, context);
            case 15:
                newState = matchTokenAt_15(token, context);
            case 16:
                newState = matchTokenAt_16(token, context);
            case 17:
                newState = matchTokenAt_17(token, context);
            case 18:
                newState = matchTokenAt_18(token, context);
            case 19:
                newState = matchTokenAt_19(token, context);
            case 20:
                newState = matchTokenAt_20(token, context);
            case 21:
                newState = matchTokenAt_21(token, context);
            case 22:
                newState = matchTokenAt_22(token, context);
            case 23:
                newState = matchTokenAt_23(token, context);
            case 24:
                newState = matchTokenAt_24(token, context);
            case 25:
                newState = matchTokenAt_25(token, context);
            case 26:
                newState = matchTokenAt_26(token, context);
            case 28:
                newState = matchTokenAt_28(token, context);
            case 29:
                newState = matchTokenAt_29(token, context);
            case 30:
                newState = matchTokenAt_30(token, context);
            case 31:
                newState = matchTokenAt_31(token, context);
            case 32:
                newState = matchTokenAt_32(token, context);
            case 33:
                newState = matchTokenAt_33(token, context);
        }
        return newState;
    }
    
    // Start
    private function matchTokenAt_0(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                build(context, token);
            return 27;
        }
        if (match_Language(context, token))
        {
                startRule(context, RuleType.Feature);
                startRule(context, RuleType.Feature_Header);
                build(context, token);
            return 1;
        }
        if (match_TagLine(context, token))
        {
                startRule(context, RuleType.Feature);
                startRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 2;
        }
        if (match_FeatureLine(context, token))
        {
                startRule(context, RuleType.Feature);
                startRule(context, RuleType.Feature_Header);
                build(context, token);
            return 3;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 0;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 0;
        }
        
        var stateComment = "State: 0 - Start";
        token.detach();
        var expectedTokens = ["#EOF", "#Language", "#TagLine", "#FeatureLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 0;
    }
    
    // GherkinDocument:0>Feature:0>Feature_Header:0>#Language:0
    private function matchTokenAt_1(token:Token, context:ParserContext):Int {
        if (match_TagLine(context, token))
        {
                startRule(context, RuleType.Tags);
                build(context, token);
            return 2;
        }
        if (match_FeatureLine(context, token))
        {
                build(context, token);
            return 3;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 1;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 1;
        }
        
        var stateComment = "State: 1 - GherkinDocument:0>Feature:0>Feature_Header:0>#Language:0";
        token.detach();
        var expectedTokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 1;
    }
    
    // GherkinDocument:0>Feature:0>Feature_Header:1>Tags:0>#TagLine:0
    private function matchTokenAt_2(token:Token, context:ParserContext):Int {
        if (match_TagLine(context, token))
        {
                build(context, token);
            return 2;
        }
        if (match_FeatureLine(context, token))
        {
                endRule(context, RuleType.Tags);
                build(context, token);
            return 3;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 2;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 2;
        }
        
        var stateComment = "State: 2 - GherkinDocument:0>Feature:0>Feature_Header:1>Tags:0>#TagLine:0";
        token.detach();
        var expectedTokens = ["#TagLine", "#FeatureLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 2;
    }
    
    // GherkinDocument:0>Feature:0>Feature_Header:2>#FeatureLine:0
    private function matchTokenAt_3(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 3;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 5;
        }
        if (match_BackgroundLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Background);
                build(context, token);
            return 6;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                startRule(context, RuleType.Description);
                build(context, token);
            return 4;
        }
        
        var stateComment = "State: 3 - GherkinDocument:0>Feature:0>Feature_Header:2>#FeatureLine:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Empty", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 3;
    }
    
    // GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:1>Description:0>#Other:0
    private function matchTokenAt_4(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Feature_Header);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                endRule(context, RuleType.Description);
                build(context, token);
            return 5;
        }
        if (match_BackgroundLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Background);
                build(context, token);
            return 6;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 4;
        }
        
       var stateComment = "State: 4 - GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:1>Description:0>#Other:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 4;

    }
    
    // GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:2>#Comment:0
    private function matchTokenAt_5(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 5;
        }
        if (match_BackgroundLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Background);
                build(context, token);
            return 6;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Feature_Header);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 5;
        }
        
        var stateComment = "State: 5 - GherkinDocument:0>Feature:0>Feature_Header:3>Feature_Description:0>Description_Helper:2>#Comment:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#BackgroundLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 5;
    }
    
    // GherkinDocument:0>Feature:1>Background:0>#BackgroundLine:0
    private function matchTokenAt_6(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Background);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 6;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 8;
        }
        if (match_StepLine(context, token))
        {
                startRule(context, RuleType.Step);
                build(context, token);
            return 9;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                startRule(context, RuleType.Description);
                build(context, token);
            return 7;
        }
        
        var stateComment = "State: 6 - GherkinDocument:0>Feature:1>Background:0>#BackgroundLine:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 6;
    }
    
    // GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:1>Description:0>#Other:0
    private function matchTokenAt_7(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Background);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                endRule(context, RuleType.Description);
                build(context, token);
            return 8;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.Description);
                startRule(context, RuleType.Step);
                build(context, token);
            return 9;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 7;
        }
        
        var stateComment = "State: 7 - GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:1>Description:0>#Other:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 7;
    }
    
    // GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:2>#Comment:0
    private function matchTokenAt_8(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Background);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 8;
        }
        if (match_StepLine(context, token))
        {
                startRule(context, RuleType.Step);
                build(context, token);
            return 9;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 8;
        }
        
        var stateComment = "State: 8 - GherkinDocument:0>Feature:1>Background:1>Background_Description:0>Description_Helper:2>#Comment:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 8;
    }
    
    // GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:0>#StepLine:0
    private function matchTokenAt_9(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_TableRow(context, token))
        {
                startRule(context, RuleType.DataTable);
                build(context, token);
            return 10;
        }
        if (match_DocStringSeparator(context, token))
        {
                startRule(context, RuleType.DocString);
                build(context, token);
            return 32;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 9;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 9;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 9;
        }
        
        var stateComment = "State: 9 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:0>#StepLine:0";
        token.detach();
        var expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 9;
    }
    
    // GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0
    private function matchTokenAt_10(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_TableRow(context, token))
        {
                build(context, token);
            return 10;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 9;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 10;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 10;
        }
        
        var stateComment = "State: 10 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0";
        token.detach();
        var expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 10;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:0>Tags:0>#TagLine:0
    private function matchTokenAt_11(token:Token, context:ParserContext):Int {
        if (match_TagLine(context, token))
        {
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Tags);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Tags);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 11;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 11;
        }
        
        var stateComment = "State: 11 - GherkinDocument:0>Feature:2>Scenario_Definition:0>Tags:0>#TagLine:0";
        token.detach();
        var expectedTokens = ["#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 11;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:0>#ScenarioLine:0
    private function matchTokenAt_12(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 12;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 14;
        }
        if (match_StepLine(context, token))
        {
                startRule(context, RuleType.Step);
                build(context, token);
            return 15;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                startRule(context, RuleType.Description);
                build(context, token);
            return 13;
        }
        
        var stateComment = "State: 12 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:0>#ScenarioLine:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 12;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:1>Description:0>#Other:0
    private function matchTokenAt_13(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                endRule(context, RuleType.Description);
                build(context, token);
            return 14;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.Description);
                startRule(context, RuleType.Step);
                build(context, token);
            return 15;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 13;
        }
        
        var stateComment = "State: 13 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:1>Description:0>#Other:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 13;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:2>#Comment:0
    private function matchTokenAt_14(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 14;
        }
        if (match_StepLine(context, token))
        {
                startRule(context, RuleType.Step);
                build(context, token);
            return 15;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 14;
        }
        
        var stateComment = "State: 14 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:1>Scenario_Description:0>Description_Helper:2>#Comment:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 14;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:0>#StepLine:0
    private function matchTokenAt_15(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_TableRow(context, token))
        {
                startRule(context, RuleType.DataTable);
                build(context, token);
            return 16;
        }
        if (match_DocStringSeparator(context, token))
        {
                startRule(context, RuleType.DocString);
                build(context, token);
            return 30;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 15;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 15;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 15;
        }
        
        var stateComment = "State: 15 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:0>#StepLine:0";
        token.detach();
        var expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 15;
    }
    
    //GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0
    private function matchTokenAt_16(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_TableRow(context, token))
        {
                build(context, token);
            return 16;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 15;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 16;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 16;
        }
        
        var stateComment = "State: 16 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0";
        token.detach();
        var expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 16;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:0>#ScenarioOutlineLine:0
    private function matchTokenAt_17(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 19;
        }
        if (match_StepLine(context, token))
        {
                startRule(context, RuleType.Step);
                build(context, token);
            return 20;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                startRule(context, RuleType.Description);
                build(context, token);
            return 18;
        }
        
        var stateComment = "State: 17 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:0>#ScenarioOutlineLine:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Empty", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 17;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:1>Description:0>#Other:0
    private function matchTokenAt_18(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                endRule(context, RuleType.Description);
                build(context, token);
            return 19;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.Description);
                startRule(context, RuleType.Step);
                build(context, token);
            return 20;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.Description);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.Description);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 18;
        }
        
        var stateComment = "State: 18 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:1>Description:0>#Other:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 18;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:2>#Comment:0
    private function matchTokenAt_19(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 19;
        }
        if (match_StepLine(context, token))
        {
                startRule(context, RuleType.Step);
                build(context, token);
            return 20;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 19;
        }
        
        var stateComment = "State: 19 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:1>ScenarioOutline_Description:0>Description_Helper:2>#Comment:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 19;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:0>#StepLine:0
    private function matchTokenAt_20(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_TableRow(context, token))
        {
                startRule(context, RuleType.DataTable);
                build(context, token);
            return 21;
        }
        if (match_DocStringSeparator(context, token))
        {
                startRule(context, RuleType.DocString);
                build(context, token);
            return 28;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 20;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 20;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 20;
        }
        
        var stateComment = "State: 20 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:0>#StepLine:0";
        token.detach();
        var expectedTokens = ["#EOF", "#TableRow", "#DocStringSeparator", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 20;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0
    private function matchTokenAt_21(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_TableRow(context, token))
        {
                build(context, token);
            return 21;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 20;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.DataTable);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 21;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 21;
        }
        
        var stateComment = "State: 21 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:0>DataTable:0>#TableRow:0";
        token.detach();
        var expectedTokens = ["#EOF", "#TableRow", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 21;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:0>Tags:0>#TagLine:0
    private function matchTokenAt_22(token:Token, context:ParserContext):Int {
        if (match_TagLine(context, token))
        {
                build(context, token);
            return 22;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.Tags);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 22;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 22;
        }
        
        var stateComment = "State: 22 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:0>Tags:0>#TagLine:0";
        token.detach();
        var expectedTokens = ["#TagLine", "#ExamplesLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 22;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:0>#ExamplesLine:0
    private function matchTokenAt_23(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 23;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 25;
        }
        if (match_TableRow(context, token))
        {
                startRule(context, RuleType.Examples_Table);
                build(context, token);
            return 26;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                startRule(context, RuleType.Description);
                build(context, token);
            return 24;
        }
        
        var stateComment = "State: 23 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:0>#ExamplesLine:0";
        var expectedTokens = ["#EOF", "#Empty", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 23;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:1>Description:0>#Other:0
    private function matchTokenAt_24(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                endRule(context, RuleType.Description);
                build(context, token);
            return 25;
        }
        if (match_TableRow(context, token))
        {
                endRule(context, RuleType.Description);
                startRule(context, RuleType.Examples_Table);
                build(context, token);
            return 26;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Description);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 24;
        }
        
        var stateComment = "State: 24 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:1>Description:0>#Other:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 24;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:2>#Comment:0
    private function matchTokenAt_25(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 25;
        }
        if (match_TableRow(context, token))
        {
                startRule(context, RuleType.Examples_Table);
                build(context, token);
            return 26;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 25;
        }
        
        var stateComment = "State: 25 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:1>Examples_Description:0>Description_Helper:2>#Comment:0";
        token.detach();
        var expectedTokens = ["#EOF", "#Comment", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 25;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:2>Examples_Table:0>#TableRow:0
    private function matchTokenAt_26(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.Examples_Table);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_TableRow(context, token))
        {
                build(context, token);
            return 26;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.Examples_Table);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.Examples_Table);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.Examples_Table);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.Examples_Table);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.Examples_Table);
                endRule(context, RuleType.Examples);
                endRule(context, RuleType.Examples_Definition);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 26;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 26;
        }
        
        var stateComment = "State: 26 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:3>Examples_Definition:1>Examples:2>Examples_Table:0>#TableRow:0";
        token.detach();
        var expectedTokens = ["#EOF", "#TableRow", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 26;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0
    private function matchTokenAt_28(token:Token, context:ParserContext):Int {
        if (match_DocStringSeparator(context, token))
        {
                build(context, token);
            return 29;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 28;
        }
        
        var stateComment = "State: 28 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0";
        token.detach();
        var expectedTokens = ["#DocStringSeparator", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 28;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0
    private function matchTokenAt_29(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 20;
        }
        if (match_TagLine(context, token))
        {
            if (lookahead_0(context, token))
            {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 22;
            }
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ExamplesLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Examples_Definition);
                startRule(context, RuleType.Examples);
                build(context, token);
            return 23;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.ScenarioOutline);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 29;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 29;
        }
        
        var stateComment = "State: 29 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:1>ScenarioOutline:2>ScenarioOutline_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0";
        token.detach();
        var expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ExamplesLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 29;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0
    private function matchTokenAt_30(token:Token, context:ParserContext):Int {
        if (match_DocStringSeparator(context, token))
        {
                build(context, token);
            return 31;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 30;
        }
        
        var stateComment = "State: 30 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0";
        token.detach();
        var expectedTokens = ["#DocStringSeparator", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 30;
    }
    
    // GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0
    private function matchTokenAt_31(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 15;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Scenario);
                endRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 31;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 31;
        }
        
        var stateComment = "State: 31 - GherkinDocument:0>Feature:2>Scenario_Definition:1>__alt0:0>Scenario:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0";
        token.detach();
        var expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 31;
    }
    
    // GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0
    private function matchTokenAt_32(token:Token, context:ParserContext):Int {
        if (match_DocStringSeparator(context, token))
        {
                build(context, token);
            return 33;
        }
        if (match_Other(context, token))
        {
                build(context, token);
            return 32;
        }
        
        var stateComment = "State: 32 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:0>#DocStringSeparator:0";
        token.detach();
        var expectedTokens = ["#DocStringSeparator", "#Other"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 32;
    }
    
    // GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0
    private function matchTokenAt_33(token:Token, context:ParserContext):Int {
        if (match_EOF(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                endRule(context, RuleType.Feature);
                build(context, token);
            return 27;
        }
        if (match_StepLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                startRule(context, RuleType.Step);
                build(context, token);
            return 9;
        }
        if (match_TagLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Tags);
                build(context, token);
            return 11;
        }
        if (match_ScenarioLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.Scenario);
                build(context, token);
            return 12;
        }
        if (match_ScenarioOutlineLine(context, token))
        {
                endRule(context, RuleType.DocString);
                endRule(context, RuleType.Step);
                endRule(context, RuleType.Background);
                startRule(context, RuleType.Scenario_Definition);
                startRule(context, RuleType.ScenarioOutline);
                build(context, token);
            return 17;
        }
        if (match_Comment(context, token))
        {
                build(context, token);
            return 33;
        }
        if (match_Empty(context, token))
        {
                build(context, token);
            return 33;
        }
        
        var stateComment = "State: 33 - GherkinDocument:0>Feature:1>Background:2>Scenario_Step:0>Step:1>Step_Arg:0>__alt1:1>DocString:2>#DocStringSeparator:0";
        token.detach();
        var expectedTokens = ["#EOF", "#StepLine", "#TagLine", "#ScenarioLine", "#ScenarioOutlineLine", "#Comment", "#Empty"];
        var error = token.isEOF
                ? new ParserException.UnexpectedEOFException(token, expectedTokens, stateComment)
                : new ParserException.UnexpectedTokenException(token, expectedTokens, stateComment);
        if (stopAtFirstError)
            throw error;

        addError(context, error);
        return 33;
    }
    
    private function lookahead_0(context:ParserContext, currentToken:Token):Bool {
        currentToken.detach();
        var token:Token = null;
        var queue:Array<Token> = new Array<Token>();
        var match:Bool = false;
        do {
            token = readToken(context);
            token.detach();
            queue.push(token);
            if (false
                || match_ExamplesLine(context, token)
            )
            {
                match = true;
                break;
            }
        } while (false
            || match_Empty(context, token)
            || match_Comment(context, token)
            || match_TagLine(context, token)
        );
        
        context.tokenQueue = context.tokenQueue.concat(queue);

        return match;
    }
}

interface Builder<T> {
    public function build(token:Token):Void;
    public function startRule(ruleType:RuleType):Void;
    public function endRule(ruleType:RuleType):Void;
    public var result(get, null):T;
    public function reset():Void;
}

interface ITokenScanner {
    public function read():Token;
}

interface ITokenMatcher {
    public function match_EOF(token:Token):Bool;
    public function match_Empty(token:Token):Bool;
    public function match_Comment(token:Token):Bool;
    public function match_TagLine(token:Token):Bool;
    public function match_FeatureLine(token:Token):Bool;
    public function match_BackgroundLine(token:Token):Bool;
    public function match_ScenarioLine(token:Token):Bool;
    public function match_ScenarioOutlineLine(token:Token):Bool;
    public function match_ExamplesLine(token:Token):Bool;
    public function match_StepLine(token:Token):Bool;
    public function match_DocStringSeparator(token:Token):Bool;
    public function match_TableRow(token:Token):Bool;
    public function match_Language(token:Token):Bool;
    public function match_Other(token:Token):Bool;
    public function reset():Void;
}