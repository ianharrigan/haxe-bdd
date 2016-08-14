package gherkin.ast;

class Node {
    public var location(default, null):Location;

    public function new(location:Location) {
        this.location = location;
    }

    private var type(get, null):String;
    private function get_type():String {
        var arr:Array<String> = Type.getClassName(Type.getClass(this)).split(".");
        return arr[arr.length - 1];
    }
}