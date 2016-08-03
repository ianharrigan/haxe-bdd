package gherkin;

import gherkin.Parser.Builder;
import gherkin.Parser.RuleType;
import gherkin.Parser.RuleTypeConverter;
import gherkin.Parser.TokenType;
import gherkin.ast.Background;
import gherkin.ast.Comment;
import gherkin.ast.DataTable;
import gherkin.ast.DocString;
import gherkin.ast.Examples;
import gherkin.ast.Feature;
import gherkin.ast.GherkinDocument;
import gherkin.ast.Location;
import gherkin.ast.Node;
import gherkin.ast.Scenario;
import gherkin.ast.ScenarioDefinition;
import gherkin.ast.ScenarioOutline;
import gherkin.ast.Step;
import gherkin.ast.TableCell;
import gherkin.ast.TableRow;
import gherkin.ast.Tag;

class AstBuilder implements Builder<GherkinDocument> {
    private var stack:Array<AstNode>;
    private var comments:Array<Comment>;
    
    public function new() {
        reset();
    }
    
    public function reset():Void {
        stack = new Array<AstNode>();
        stack.push(new AstNode(RuleType.None));
        
        comments = new Array<Comment>();
    }
    
    private var currentNode(get, null):AstNode;
    private function get_currentNode():AstNode {
        return stack[stack.length - 1];
    }
    
    public function build(token:Token):Void {
        var ruleType:RuleType = RuleTypeConverter.convert(token.matchedType);
        if (token.matchedType == TokenType.Comment) {
            comments.push(new Comment(getLocation(token, 0), token.matchedText));
        } else {
            currentNode.add(ruleType, token);
        }
    }
    
    public function startRule(ruleType:RuleType):Void {
        stack.push(new AstNode(ruleType));
    }
    
    public function endRule(ruleType:RuleType):Void {
        var node:AstNode = stack.pop();
        var transformedNode:Dynamic = getTransformedNode(node);
        currentNode.add(node.ruleType, transformedNode);
    }
    
    public function getTransformedNode(node:AstNode):Dynamic {
        switch (node.ruleType) {
            case RuleType.Step:
                var stepLine:Token = node.getToken(TokenType.StepLine);
                var stepArg:Node = node.getSingle(RuleType.DataTable, null);
                if (stepArg == null) {
                    stepArg = node.getSingle(RuleType.DocString, null);
                }
                return new Step(getLocation(stepLine, 0), stepLine.matchedKeyword, stepLine.matchedText, stepArg);
             
            case RuleType.DocString:                
                var separatorToken:Token = node.getTokens(TokenType.DocStringSeparator)[0];
                var contentType:String = separatorToken.matchedText.length > 0 ? separatorToken.matchedText : null;
                var lineTokens:Array<Token> = node.getTokens(TokenType.Other);
                var content:StringBuf = new StringBuf();
                var newLine:Bool = false;
                for (lineToken in lineTokens) {
                    if (newLine) content.add("\n");
                    newLine = true;
                    content.add(lineToken.matchedText);
                }
                return new DocString(getLocation(separatorToken, 0), contentType, content.toString());
                
            case RuleType.DataTable:
                var rows:Array<TableRow> = getTableRows(node);
                return new DataTable(rows);
                
            case RuleType.Background:
                var backgroundLine:Token = node.getToken(TokenType.BackgroundLine);
                var description:String = getDescription(node);
                var steps:Array<Step> = getSteps(node);
                return new Background(getLocation(backgroundLine, 0), backgroundLine.matchedKeyword, backgroundLine.matchedText, description, steps);

            case RuleType.Scenario_Definition:
                var tags:Array<Tag> = getTags(node);
                var scenarioNode:AstNode = node.getSingle(RuleType.Scenario, null);
                
                if (scenarioNode != null) {
                    var scenarioLine:Token = scenarioNode.getToken(TokenType.ScenarioLine);
                    var description:String = getDescription(scenarioNode);
                    var steps:Array<Step> = getSteps(scenarioNode);
                    
                    return new Scenario(tags, getLocation(scenarioLine, 0), scenarioLine.matchedKeyword, scenarioLine.matchedText, description, steps);
                } else {
                    var scenarioOutlineNode:AstNode = node.getSingle(RuleType.ScenarioOutline, null);
                    if (scenarioOutlineNode == null) {
                        throw "Internal grammar error";
                    }
                    
                    var scenarioOutlineLine:Token = scenarioOutlineNode.getToken(TokenType.ScenarioOutlineLine);
                    var description:String = getDescription(scenarioOutlineNode);
                    var steps:Array<Step> = getSteps(scenarioOutlineNode);
                    
                    var examplesList:Array<Examples> = scenarioOutlineNode.getItems(RuleType.Examples_Definition);

                    return new ScenarioOutline(tags, getLocation(scenarioOutlineLine, 0), scenarioOutlineLine.matchedKeyword, scenarioOutlineLine.matchedText, description, steps, examplesList);
                }
            
            case RuleType.Examples_Definition:
                var tags:Array<Tag> = getTags(node);
                var examplesNode:AstNode = node.getSingle(RuleType.Examples, null);
                var examplesLine:Token = examplesNode.getToken(TokenType.ExamplesLine);
                var description:String = getDescription(examplesNode);
                var rows:Array<TableRow> = examplesNode.getSingle(RuleType.Examples_Table, null);
                var tableHeader:TableRow = rows != null && !(rows.length == 0) ? rows[0] : null;
                var tableBody:Array<TableRow> = rows != null && !(rows.length == 0) ? rows.slice(1, rows.length) : null;
                return new Examples(getLocation(examplesLine, 0), tags, examplesLine.matchedKeyword, examplesLine.matchedText, description, tableHeader, tableBody);
            
            case RuleType.Examples_Table:
                return getTableRows(node);
            
            case RuleType.Description:
                var lineTokens:Array<Token> = node.getTokens(TokenType.Other);
                // Trim trailing empty lines
                var end:Int = lineTokens.length;
                var matcher:EReg = new EReg("\\s*", "g");
                while (end > 0 && matcher.match(lineTokens[end - 1].matchedText)) {
                    end--;
                }
                lineTokens = lineTokens.slice(0, end);
                
                return gherkin.StringUtils.join(new StringUtils.TokenToString(), "\n", lineTokens);
                
            case RuleType.Feature:
                var header:AstNode = node.getSingle(RuleType.Feature_Header, new AstNode(RuleType.Feature_Header));
                if (header == null) return null;
                var tags:Array<Tag> = getTags(header);
                var featureLine:Token = header.getToken(TokenType.FeatureLine);
                if (featureLine == null) return null;
                var scenarioDefinitions:Array<ScenarioDefinition> = new Array<ScenarioDefinition>();
                var background:Background = node.getSingle(RuleType.Background, null);
                if (background != null) scenarioDefinitions.push(background);
                scenarioDefinitions = scenarioDefinitions.concat(node.getItems(RuleType.Scenario_Definition));
                var description:String = getDescription(header);
                if (featureLine.matchedGherkinDialect == null) return null;
                var language:String = featureLine.matchedGherkinDialect.language;

                return new Feature(tags, getLocation(featureLine, 0), language, featureLine.matchedKeyword, featureLine.matchedText, description, scenarioDefinitions);
            
            case RuleType.GherkinDocument:                
                var feature:Feature = node.getSingle(RuleType.Feature, null);
                
                return new GherkinDocument(feature, comments);
            case _:    
        }
        return node;
    }
    
    private function getTableRows(node:AstNode):Array<TableRow> {
        var rows:Array<TableRow> = new Array<TableRow>();
        for (token in node.getTokens(TokenType.TableRow)) {
            rows.push(new TableRow(getLocation(token, 0), getCells(token)));
        }
        ensureCellCount(rows);
        return rows;
    }
    
    private function ensureCellCount(rows:Array<TableRow>):Void {
        if (rows.length == 0) return;
        
        var cellCount:Int = rows[0].cells.length;
        for (row in rows) {
            if (row.cells.length != cellCount) {
                throw new ParserException.AstBuilderException("inconsistent cell count within the table", row.location);
            }
        }
    }
    
    private function getCells(token:Token):Array<TableCell> {
        var cells:Array<TableCell> = new Array<TableCell>();
        for (cellItem in token.matchedItems) {
            cells.push(new TableCell(getLocation(token, cellItem.column), cellItem.text));
        }
        return cells;
    }
    
    private function getSteps(node:AstNode):Array<Step> {
        return node.getItems(RuleType.Step);
    }
    
    private function getLocation(token:Token, column:Int):Location {
        return column == 0 ? token.location : new Location(token.location.line, column);
    }
    
    private function getDescription(node:AstNode):String {
        return node.getSingle(RuleType.Description, null);
    }
    
    private function getTags(node:AstNode):Array<Tag> {
        var tagsNode:AstNode = node.getSingle(RuleType.Tags, new AstNode(RuleType.None));
        if (tagsNode == null) {
            return new Array<Tag>();
        }
        
        var tokens:Array<Token> = tagsNode.getTokens(TokenType.TagLine);
        var tags:Array<Tag> = new Array<Tag>();
        for (token in tokens) {
            for (tagItem in token.matchedItems) {
                tags.push(new Tag(getLocation(token, tagItem.column), tagItem.text));
            }
        }
        return tags;
    }
    
    public var result(get, null):GherkinDocument;
    private function get_result():GherkinDocument {
        return currentNode.getSingle(RuleType.GherkinDocument, null);
    }
}