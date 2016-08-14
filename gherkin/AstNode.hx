package gherkin;
import gherkin.Parser.RuleType;
import gherkin.Parser.RuleTypeConverter;
import gherkin.Parser.TokenType;

class AstNode {
    private var subItems:Map<RuleType, Array<Dynamic>> = new Map<RuleType, Array<Dynamic>>();
    public var ruleType(default, null):RuleType;

    public function new(ruleType:RuleType) {
        this.ruleType = ruleType;
    }

    public function add(ruleType:RuleType, obj:Dynamic):Void {
        var items:Array<Dynamic> = subItems.get(ruleType);
        if (items == null) {
            items = new Array<Dynamic>();
            subItems.set(ruleType, items);
        }
        items.push(obj);
    }

    public function getSingle<T>(ruleType:RuleType, defaultResult:T):T {
        var items:Array<Dynamic> = getItems(ruleType);
        return (items.length == 0 ? defaultResult : items[0]);
    }

    public function getItems<T>(ruleType:RuleType):Array<T> {
        var items:Array<T> = cast subItems.get(ruleType);
        if (items == null) {
            return [];
        }
        return items;
    }

    public function getToken(tokenType:TokenType):Token {
        var ruleType:RuleType = RuleTypeConverter.convert(tokenType);
        return getSingle(ruleType, new Token(null, null));
    }

    public function getTokens(tokenType:TokenType):Array<Token> {
        return getItems(RuleTypeConverter.convert(tokenType));
    }
}