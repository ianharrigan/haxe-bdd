package bdd.runner.script;

import bdd.runner.steps.definitions.StepDefinition;

class Script {
    public var stepDefinitions:Array<StepDefinition> = new Array<StepDefinition>();

    public var originalContent:String;
    public function new(scriptContent:String = null) {
        //originalContent = scriptContent;

        //trace(scriptContent);
        //parseStepDefs(scriptContent);
        if (scriptContent != null) {
            addScript(scriptContent);
        }
    }

    public function addScript(scriptContent:String) {
        if (originalContent == null) {
            originalContent == "";
        }
        originalContent += StringTools.trim(scriptContent) + "\n";
        parseStepDefs(scriptContent);
    }

    private function parseStepDefs(s:String):Void {
        if (s == null) {
            return;
        }
        //stepDefinitions = new Array<StepDefinition>();

        var n1:Int = s.indexOf("step ");
        while (n1 != -1) {
            var n2:Int = n1 + 5;
            var n3:Int = s.indexOf("{", n2);

            var defLine:String = s.substring(n2, n3);
            var defArr:Array<String> = defLine.split(" do ");

            var paramsString:String = StringTools.trim(defArr.pop());
            paramsString = StringTools.trim(StringTools.replace(paramsString, "|", ""));
            var params:Array<String> = paramsString.split(",");

            var regexp:String = StringTools.trim(defArr.join(" do "));
            regexp = regexp.substring(1, regexp.length - 1);

            var stepDef:StepDefinition = new StepDefinition();
            stepDef.regexp = regexp;
            for (param in params) {
                param = StringTools.trim(param);
                if (param.length == 0) {
                    continue;
                }
                stepDef.paramNames.push(param);
            }


            n1 = s.indexOf("step ", n2);
            var n4:Int = n1;
            if (n4 == -1) {
                n4 = s.length;
            }
            var body:String = s.substring(n3, n4);
            stepDef.functionBody = body;
            stepDefinitions.push(stepDef);
        }
    }

    public function parseHookDefs(s:String):Void {
        var isBeforeHook:Bool = false;
        var n1:Int = s.indexOf("before ");
        if (n1 != -1) {
            isBeforeHook = true;
        } else {
            n1 = s.indexOf("after ");
        }

        while (n1 != -1) {

        }

        trace(n1);
    }

    public function buildScript():String {
        var s:String = '';
        for (stepDef in stepDefinitions) {
            s += 'function ${stepDef.functionName}(${stepDef.paramNames.join(",")}) ';
            s += stepDef.functionBody;
        }
        return s;
    }

}