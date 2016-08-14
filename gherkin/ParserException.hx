package gherkin;
import gherkin.StringUtils.ParserExceptionToString;
import gherkin.ast.Location;

class ParserException {
    public var message(default, default):String;
    public var location(default, default):Location;

    public function new(message:String, location:Location = null) {
        if (location == null) {
            this.message = message;
        } else {
            this.message = getMessage(message, location);
        }
        this.location = location;
    }

    public function toString():String {
        return message;
    }

    private static function getMessage(message:String, location:Location):String {
        return '(${location.line}:${location.column}): ${message}';
    }
}

class NoSuchLanguageException extends ParserException {
    public function new(language:String, location:Location = null) {
        super("Language not supported: " + language, location);
    }
}

class AstBuilderException extends ParserException {
    public function new(message:String, location:Location = null) {
        super(message, location);
    }
}

class UnexpectedTokenException extends ParserException {
    public var stateComment(default, null):String;
    public var expectedTokenTypes(default, null):Array<String>;
    public var receivedToken(default, null):Token;

    public function new(receivedToken:Token, expectedTokenTypes:Array<String>, stateComment:String) {
        super(getMessage(receivedToken, expectedTokenTypes), getLocation(receivedToken));
        this.receivedToken = receivedToken;
        this.expectedTokenTypes = expectedTokenTypes;
        this.stateComment = stateComment;
    }

    private static function getMessage(receivedToken:Token, expectedTokens:Array<String>):String {
        return 'expected: ${gherkin.StringUtils.joinString(", ", expectedTokens)}, got "${StringTools.trim(receivedToken.tokenValue)}"';
    }

    private static function getLocation(receivedToken:Token):Location {
        return receivedToken.location.column > 1
            ? receivedToken.location
            : new Location(receivedToken.location.line, receivedToken.line.indent() + 1);
    }
}

class UnexpectedEOFException extends ParserException {
    public var stateComment(default, null):String;
    public var expectedTokenTypes(default, null):Array<String>;

    public function new(receivedToken:Token, expectedTokenTypes:Array<String>, stateComment:String) {
        super(getMessage(expectedTokenTypes), receivedToken.location);
        this.expectedTokenTypes = expectedTokenTypes;
        this.stateComment = stateComment;
    }

    private static function getMessage(expectedTokens:Array<String>):String {
        return "unexpected end of file: " + gherkin.StringUtils.joinString(", ", expectedTokens);
    }
}

class CompositeParserException extends ParserException {
    public var errors(default, null):Array<ParserException>;

    public function new(errors:Array<ParserException>) {
        super(getMessage(errors));
        this.errors = errors;
    }

    private static function getMessage(errors:Array<ParserException>):String {
        if (errors == null) throw "null errors";

        return "Parser errors:\n" + gherkin.StringUtils.join(new ParserExceptionToString(), "\n", errors);
    }
}