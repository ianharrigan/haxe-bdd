package gherkin;

class StringUtils {
    public static function joinString(separator:String, items:Array<String>):String {
        return join(new DefaultToString(), separator, items);
    }

    public static function join<T>(toString:ToString<T>, separator:String, items:Iterable<T>):String {
        var sb:StringBuf = new StringBuf();
        var useSeparator:Bool = false;
        for (item in items) {
            if (useSeparator) sb.add(separator);
            useSeparator = true;
            sb.add(toString.toString(item));
        }
        return sb.toString();
    }
}

interface ToString<T> {
    public function toString(o:T):String;
}

class DefaultToString implements ToString<String> {
    public function new() {
    }

    public function toString(o:String):String {
        return o;
    }
}

class TokenToString implements ToString<Token> {
    public function new() {
    }

    public function toString(t:Token):String {
        return t.matchedText;
    }
}

class ParserExceptionToString implements ToString<ParserException> {
    public function new() {
    }

    public function toString(e:ParserException):String {
        return e.message;
    }
}