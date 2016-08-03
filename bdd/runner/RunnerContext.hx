package bdd.runner;

class RunnerContext {
    public var tags:String;
    public var statics:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var objects:Map<String, Dynamic> = new Map<String, Dynamic>();
    public var functions:Map<String, Dynamic> = new Map<String, Dynamic>();
    
    public function new() {
        addFunction("assert", Runner.assert);
        addFunction("assert_not", Runner.assert_not);
        addFunction("debug", Runner.debug);
        addFunction("info", Runner.info);
        addFunction("error", Runner.error);
        addFunction("warning", Runner.warning);
    }
    
    public function addStatic(name:String, object:Dynamic) {
        statics.set(name, object);
    }
    
    public function addObject(name:String, object:Dynamic) {
        objects.set(name, object);
    }
    
    public function addFunction(name:String, object:Dynamic) {
        functions.set(name, object);
    }
    
}