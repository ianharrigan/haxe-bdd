package gherkin;

import gherkin.ast.Location;

interface IGherkinDialectProvider {
    public var defaultDialect(get, null):GherkinDialect;
    
    public function getDialect(language:String, location:Location):GherkinDialect;
}