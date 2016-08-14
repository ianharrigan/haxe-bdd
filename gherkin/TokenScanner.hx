package gherkin;

import gherkin.ast.Location;

/**
 * <p>
 * The scanner reads a gherkin doc (typically read from a .feature file) and creates a token
 * for each line. The tokens are passed to the parser, which outputs an AST (Abstract Syntax Tree).</p>
 *
 * <p>
 * If the scanner sees a # language header, it will reconfigure itself dynamically to look for
 * Gherkin keywords for the associated language. The keywords are defined in gherkin-languages.json.</p>
 */
class TokenScanner implements Parser.ITokenScanner {
    private var lines:Array<String>;
    private var lineNumber:Int = 0;

    public function new(source:String) {
        lines = source.split("\n");
        lineNumber = 0;
    }

    public function read():Token {
        var line:String = null;
        if (lineNumber < lines.length) {
            line = lines[lineNumber];
            lineNumber++;
        }
        var location:Location = new Location(lineNumber, 0);
        return line == null ? new Token(null, location) : new Token(new GherkinLine(line), location);
    }

}