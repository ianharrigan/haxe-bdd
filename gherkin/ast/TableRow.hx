package gherkin.ast;

class TableRow extends Node {
    public var cells(default, null):Array<TableCell>;
    
    public function new(location:Location, cells:Array<TableCell>) {
        super(location);
        this.cells = cells;
    }
}