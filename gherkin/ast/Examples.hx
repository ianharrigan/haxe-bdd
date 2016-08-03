package gherkin.ast;

class Examples extends Node {
    public var tags(default, null):Array<Tag>;
    public var keyword(default, null):String;
    public var name(default, null):String;
    public var description(default, null):String;
    public var tableHeader(default, null):TableRow;
    public var tableBody(default, null):Array<TableRow>;
    
    public function new(location:Location, tags:Array<Tag>, keyword:String, name:String, description:String, tableHeader:TableRow, tableBody:Array<TableRow>) {
        super(location);
        this.tags = tags;
        this.keyword = keyword;
        this.name = name;
        this.description = description;
        this.tableHeader = tableHeader;
        this.tableBody = tableBody != null ? tableBody : null;
    }
}