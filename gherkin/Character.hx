package gherkin;

class Character {
    public static function isWhitespace(s:String):Bool {
        return (s == " " || s == "\n" || s == "\r" || s == "\t");
    }
}