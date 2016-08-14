package bdd.runner;

import bdd.runner.script.Script;
import bdd.runner.script.ScriptInterp;
import bdd.runner.steps.definitions.StepDefinition;
import gherkin.ast.DataTable;
import gherkin.ast.GherkinDocument;
import gherkin.ast.Scenario;
import gherkin.ast.Step;
import gherkin.ast.Tag;
import haxe.CallStack;
import hscript.Parser;
import promhx.Deferred;
import promhx.Promise;

import ANSI;

class Runner {
    private var doc:GherkinDocument;
    private var script:Script;

    public function new(doc:GherkinDocument, script:Script) {
        this.doc = doc;
        this.script = script;
    }

    private var stepsToStepDefs:Map<String, StepDefinition>;

    public function prepare():Void {
        stepsToStepDefs = new Map<String, StepDefinition>();

        for (child in doc.feature.children) {
            var scenario:Scenario = cast child;
            for (step in scenario.steps) {
                var matchCount:Int = 0;
                var matchedStepDef:StepDefinition = null;
                var multipleMatches:Array<StepDefinition> = new Array<StepDefinition>();
                for (stepDef in script.stepDefinitions) {
                    var matcher:EReg = new EReg(stepDef.regexp, "g");
                    if (matcher.match(step.text) == true) {
                        matchCount++;
                        matchedStepDef = stepDef;
                        multipleMatches.push(stepDef);
                    }
                }
                if (matchCount == 0) {
                    throw "No matches found for: " + step.text;
                } else if (matchCount > 1) {
                    var e:String = "Mulitple matches found for: " + step.text + ":\n";
                    for (m in multipleMatches) {
                        e += m.regexp + "\n";
                    }
                    throw e;
                } else {
                    stepsToStepDefs.set(step.text, matchedStepDef);
                }
            }
        }
    }

    public static function assert(o1:Dynamic, o2:Dynamic) {
        if (o1 != o2) {
            throw '${o1} != ${o2}';
        }
    }

    public static function assert_not(o1:Dynamic, o2:Dynamic) {
        if (o1 == o2) {
            throw 'Expected ${o1} to not equal ${o2}';
        }
    }

    public static function debug(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(Magenta) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function info(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(Green) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function error(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(Red) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function success(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(Green) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function warning(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(Yellow) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function data(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(White) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function log(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function cyan(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(Cyan) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

    public static function deferred():Deferred<Dynamic> {
        return new Deferred<Dynamic>();
    }

    public static function promise(d:Deferred<Dynamic>):Promise<Dynamic> {
        return new Promise(d);
    }

    public static function magenta(data:Dynamic, newLine:Bool = true) {
        Sys.stdout().writeString(ANSI.set(Magenta) + data + (newLine == true ? "\n" : ""));
        Sys.stdout().writeString(ANSI.set(DefaultForeground) + "");
    }

            var skip:Bool = false;
            var passedCount:Int = 0;
            var skippedCount:Int = 0;
            var failedCount:Int = 0;

        var interp:ScriptInterp = null;
        var parser:Parser = null;
        var hscript:String = null;


        var scenarios:Array<Scenario>;
        var scenarioIndex:Int = 0;

        var steps:Array<Step>;

    public function nextScenario() {
        if (scenarios.length == 0) {
            if (_fn != null) {
                _fn(this);
            }
            return;
        }

        skip = false;
        passedCount = 0;
        skippedCount = 0;
        failedCount = 0;

        var scenario:Scenario = scenarios[0];
        var title:String = " " + StringTools.trim(scenario.name) + " ";
        var x:Int = Std.int((80 - title.length) / 2);
        title = StringTools.lpad(title, "-", title.length + x);
        title = StringTools.rpad(title, "-", title.length + x);
        log(title + "\n");

        steps = new Array<Step>();
        for (step in scenario.steps) {
            steps.push(step);
        }

        scenarios.remove(scenario);

        nextStep();
    }

    public function nextStep() {
        Sys.sleep(0);

        if (steps.length == 0) {
            success("\n    passed: " + passedCount, false);
            if (failedCount > 0) {
                log(", ", false);
                error("failed: " + failedCount, false);
            }
            if (skippedCount > 0) {
                log(", ", false);
                warning("skipped: " + skippedCount, false);
            }

            success("\n");

            nextScenario();
            return;
        }

        var step:Step = steps[0];
        steps.remove(step);

        var r = runStep(step);
        if (Std.is(r, Promise)) {
            var p:Promise<Dynamic> = cast r;
            p.then(function(e) {
                printLine(step.keyword + step.text, success, buildParamRanges(step));
                var dataTable:DataTable = cast step.argument;
                if (dataTable != null) {
                    prettyPrintTable(dataTable, success);
                }
                passedCount++;
                nextStep();
            }).catchError(function(e) {
               handleError(e, step);
               nextStep();
            });
        } else {
            nextStep();
        }
    }

    private var _fn:Dynamic->Void;
    public function run(context:RunnerContext = null, fn:Dynamic->Void):Void {
        prepare();
        _fn = fn;
        if (context == null) {
            context = new RunnerContext();
        }
        interp = new ScriptInterp();
        parser = new Parser();
        hscript = script.buildScript();

        var program = parser.parseString(hscript);
        interp.variables.set("DataTable", DataTable);

        for (s in context.statics.keys()) {
            interp.variables.set(s, context.statics.get(s));
        }
        for (f in context.functions.keys()) {
            interp.variables.set(f, context.functions.get(f));
        }
        for (o in context.objects.keys()) {
            interp.variables.set(o, context.objects.get(o));
        }

        interp.execute(program);

        scenarioIndex = 0;
        scenarios = new Array<Scenario>();
        for (child in doc.feature.children) {
            var scenario:Scenario = cast child;
            if (matchTags(scenario.tags, context.tags) == false) {
                continue;
            }

            scenarios.push(scenario);
        }

        nextScenario();
    }

    private function buildParamRanges(step:Step):Array<Dynamic> {
        var paramRanges:Array<Dynamic> = new Array<Dynamic>();
        var stepDef:StepDefinition = stepsToStepDefs.get(step.text);
        var dataTable:DataTable = cast step.argument;
        var matcher:EReg = new EReg(stepDef.regexp, "g");
        matcher.match(step.text);
        var i:Int = 0;
        for (n in 0...stepDef.paramNames.length) {
            if (dataTable != null && n >= stepDef.paramNames.length - 1) {
                continue;
            }
            var t:Int = step.text.indexOf(matcher.matched(n + 1), i + 1);
            i = t;
            var p = {
                start: t + step.keyword.length,
                length: matcher.matched(n + 1).length
            };
            paramRanges.push(p);
        }
        return paramRanges;
    }

    @:access(hscript.Interp)
    private function runStep(step:Step):Dynamic {
        var r:Dynamic = null;

        var stepDef:StepDefinition = stepsToStepDefs.get(step.text);
        var matcher:EReg = new EReg(stepDef.regexp, "g");
        matcher.match(step.text);
        var paramValues:Array<String> = new Array<String>();

        var dataTable:DataTable = cast step.argument;

        var i:Int = 0;
        for (n in 0...stepDef.paramNames.length) {
            if (dataTable != null && n >= stepDef.paramNames.length - 1) {
                continue;
            }
            paramValues.push("\"" + matcher.matched(n + 1) + "\"");
        }

        if (dataTable != null) {
            paramValues.push("DataTable.fromJSON(\"" + dataTable.toJSON() + "\")");
        }

        var call:String = '${stepDef.functionName}(${paramValues.join(",")})';
        try {
            if (skip == false) {
                r = interp.expr(parser.parseString(call));
                if (Std.is(r, Promise) == false) {
                    printLine(step.keyword + step.text, success, buildParamRanges(step));
                    if (dataTable != null) {
                        prettyPrintTable(dataTable, success);
                    }
                    passedCount++;
                }
            } else {
                printLine(step.keyword + step.text, warning, buildParamRanges(step));
                if (dataTable != null) {
                    prettyPrintTable(dataTable, warning);
                }
                skippedCount++;
            }
        } catch (e:Dynamic) {
            handleError(e, step);
        }
        return r;
    }

    @:access(hscript.Interp)
    private function handleError(e:Dynamic, step:Step) {
        var dataTable:DataTable = cast step.argument;

        printLine(step.keyword + step.text, error, buildParamRanges(step));
        if (dataTable != null) {
            prettyPrintTable(dataTable, error);
        }

        var n1:Int = interp.curExpr.pmin;
        var n2:Int = interp.curExpr.pmax;
        n1 = startOfLine(hscript, n1);
        n2 = endOfLine(hscript, n2);

        var start:Int = n1;
        var prevLines:Array<String> = new Array<String>();
        for (i in 0...2) {
            var prevN1:Int = startOfLine(hscript, start - 1);
            var prevN2:Int = endOfLine(hscript, prevN1 + 1);
            var line:String = hscript.substring(prevN1, prevN2);
            start = prevN1;
            if (line.indexOf("function") == -1) {
                prevLines.push(line);
            }
        }

        start = n2;
        var nextLines:Array<String> = new Array<String>();
        for (i in 0...2) {
            var nextN1:Int = endOfLine(hscript, start + 1);
            var nextN2:Int = endOfLine(hscript, nextN1 + 1);
            var line:String = hscript.substring(nextN1, nextN2);
            start = nextN1;
            if (line.indexOf("function") == -1) {
                nextLines.push(line);
            }
        }


        error("");
        error("    ERROR: " + e);
        prevLines.reverse();
        for (line in prevLines) {
            line = StringTools.trim(line);
            data("      " + line);
        }

        error("    > " + StringTools.trim(hscript.substring(n1, n2)));

        for (line in nextLines) {
            line = StringTools.trim(line);
            data("      " + line);
        }

        skip = true;
        error("");
        failedCount++;
    }

    private function startOfLine(s:String, from:Int):Int {
        var n = from;
        while (n != 0) {
            if (s.charAt(n) == "\n") {
                break;
            }
            n--;
        }
        return n;
    }

    private function endOfLine(s:String, from:Int) {
        var n = from;
        while (n < s.length - 1) {
            if (s.charAt(n) == "\n") {
                break;
            }
            n++;
        }
        return n;
    }

    private function matchTags(tags:Array<Tag>, allowedTags:String):Bool {
        if (allowedTags == null || allowedTags.length == 0) {
            return true;
        }

        var scenarioTags:Array<String> = new Array<String>();
        for (t in tags) {
            scenarioTags.push(t.name);
        }

        var allowed:Bool = false;
        var allowedArray:Array<String> = allowedTags.split(" ");
        for (allowedTag in allowedArray) {
            if (scenarioTags.indexOf(allowedTag) != -1) {
                allowed = true;
                break;
            }
        }
        return allowed;
    }

    private static function printLine(line:String, printFn:Dynamic->Bool->Void, ranges:Array<Dynamic>, indent:String = "    ") {
        if (ranges == null || ranges.length == 0) {
            printFn(indent + line, true);
        } else {
            var full:String = line;
            var start:Int = 0;
            var end:Int = 0;
            printFn(indent, false);
            for (p in ranges) {
                end = p.start;
                var before:String = full.substring(start, end);
                var param:String = full.substring(end, end + p.length);
                printFn(before, false);
                data(param, false);
                start = end + p.length;
            }

            if (start < full.length) {
                var after:String = full.substring(start, start + full.length);
                printFn(after, false);
            }
            printFn("\n", false);
        }
    }

    private static function prettyPrintTable(dataTable:DataTable, printFn:Dynamic->Bool->Void, indent:String = "        ") {
        var sizes:Map<Int, Int> = new Map<Int, Int>();
        var n:Int = 0;
        if (dataTable.header != null) {
            for (h in dataTable.header) {
                sizes.set(n, h.length);
                n++;
            }
        }
        for (row in dataTable.rows) {
            n = 0;
            for (c in row.cells) {
                if (sizes.exists(n) == false) {
                    sizes.set(n, 0);
                }
                if (c.value.length > sizes.get(n)) {
                    sizes.set(n, c.value.length);
                }
                n++;
            }
        }

        for (row in  dataTable.rows) {
            n = 0;
            for (c in row.cells) {
                var size = sizes.get(n);
                var value = " " + c.value + " ";
                for (x in 0...size - c.value.length) {
                    value += " ";
                }
                printFn((n == 0 ? indent + "|" : ""), false);
                data(value, false);
                printFn("|", false);
                n++;
            }
            printFn("", true);
        }
    }
}