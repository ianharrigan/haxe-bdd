package bdd.runner;

import gherkin.AstBuilder;
import gherkin.Parser;
import gherkin.ast.GherkinDocument;
import sys.io.File;
import bdd.runner.runtime.FeatureExpander;
import bdd.runner.script.Script;

class FeatureRunner extends Runner {
    public function new(featureFile:String, stepDefs:Array<String>) {
        var parser:Parser<GherkinDocument> = new Parser<GherkinDocument>(new AstBuilder());
		var doc:GherkinDocument = parser.parseString(File.getContent(featureFile));
        
        var expander:FeatureExpander = new FeatureExpander();
        doc = expander.expand(doc);
        
        // TODO: need to be able to process more than one
        var script:Script = new Script();
        for (stepDef in stepDefs) {
            script.addScript(File.getContent(stepDef));
        }
        
        super(doc, script);
    }
}