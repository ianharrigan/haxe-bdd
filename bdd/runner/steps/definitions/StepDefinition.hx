package bdd.runner.steps.definitions;

class StepDefinition {
    public var regexp:String;
    public var paramNames:Array<String> = new Array<String>();
    public var functionBody:String;

    public function new() {

    }

    public var functionName(get, null):String;
    private function get_functionName():String {
        var f:String = regexp;
        f = StringTools.replace(f, " ", "_");
        f = StringTools.replace(f, "^", "");
        f = StringTools.replace(f, "(", "");
        f = StringTools.replace(f, ")", "");
        f = StringTools.replace(f, "[", "");
        f = StringTools.replace(f, "]", "");
        f = StringTools.replace(f, "\"", "");
        f = StringTools.replace(f, "'", "");
        f = StringTools.replace(f, "*", "");
        f = StringTools.replace(f, "$", "");
        f = StringTools.replace(f, ".", "");
        f = StringTools.replace(f, ":", "_");
        f = StringTools.replace(f, ",", "_");
        f = StringTools.replace(f, "?", "_");
        return f;
    }

    public function toString():String {
        return 'regexp: ${regexp}, param names: ${paramNames}, function: ${functionName}, body: ${functionBody}';
    }
}