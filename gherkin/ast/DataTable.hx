package gherkin.ast;
import haxe.Json;

class DataTable extends Node {
    public var rows(default, null):Array<TableRow>;
    public var header:Array<String>;
    
    public function new(rows:Array<TableRow>) {
        super(rows[0].location);
        this.rows = rows;
    }
    
    public function normalise(cols:Array<String>):DataTable {
        var copy:DataTable = fromJSON(toJSON());
        var firstRow:TableRow = copy.rows[0];
        var firstColumns:Array<String> = new Array<String>();
        for (cell in firstRow.cells) {
            firstColumns.push(cell.value);
        }
        trace(firstColumns);
        trace(cols);
        if (firstColumns.toString() == cols.toString()) { // remove first row
            copy.rows = copy.rows.slice(1);
        }
        copy.header = cols;
        return copy;
    }
    
    public function get(id:String):TableRow {
        var row = null;
        for (test in rows) {
            if (test.cells[0].value == id) {
                row = test;
                break;
            }
        }
        return row;
    }
    
    public function value(id:String):String {
        var value = null;
        var row = get(id);
        if (row != null) {
            value = row.cells[1].value;
        }
        return value;
    }
    
    public function toJSON():String {
        var json:String = Json.stringify(rows);
        json = StringTools.replace(json, "\"", "'");
        return json;
    }
    
    public static function fromJSON(json:String) {
        json = StringTools.replace(json, "'", "\"");

        var rs:Array<Dynamic> = Json.parse(json);
        var rows:Array<TableRow> = new Array<TableRow>();
        for (r in rs) {
            var cs:Array<Dynamic> = r.cells;
            var cells:Array<TableCell> = new Array<TableCell>();
            for (c in cs) {
                var tc:TableCell = new TableCell(new Location(c.location.line, c.location.column), c.value);
                cells.push(tc);
            }
            var tr:TableRow = new TableRow(new Location(r.location.line, r.location.column), cells);
            rows.push(tr);
        }
        
        
        return new DataTable(rows);
    }
}