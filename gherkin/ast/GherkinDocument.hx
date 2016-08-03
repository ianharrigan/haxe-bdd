package gherkin.ast;

class GherkinDocument extends Node {
    public var feature(default, null):Feature;
    public var comments(default, null):Array<Comment>;
    
    public function new(feature:Feature, comments:Array<Comment>) {
        super(null);
        this.feature = feature;
        this.comments = comments;
    }
}