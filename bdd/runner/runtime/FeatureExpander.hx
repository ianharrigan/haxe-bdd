package bdd.runner.runtime;

import gherkin.ast.Background;
import gherkin.ast.DataTable;
import gherkin.ast.Feature;
import gherkin.ast.GherkinDocument;
import gherkin.ast.Scenario;
import gherkin.ast.ScenarioDefinition;
import gherkin.ast.ScenarioOutline;
import gherkin.ast.Step;
import gherkin.ast.TableCell;
import gherkin.ast.TableRow;
import gherkin.ast.Tag;

class FeatureExpander {
    public var expandedDoc:GherkinDocument;

    public function new() {
    }

    public function expand(doc:GherkinDocument):GherkinDocument {

        var newChildren:Array<ScenarioDefinition> = new Array<ScenarioDefinition>();
        var backgroundSteps:Array<Step> = null;

        for (child in doc.feature.children) {
            if (Std.is(child, Background)) {
                var background:Background = cast child;
                backgroundSteps = background.steps;
            } else if (Std.is(child, ScenarioOutline)) {
                var scenarioOutline:ScenarioOutline = cast child;
                for (examples in scenarioOutline.examples) {
                    var header:TableRow = examples.tableHeader;
                    var rows:Array<TableRow> = examples.tableBody;

                    for (row in rows) {
                        var newScenarioSteps:Array<Step> = new Array<Step>();
                        // copy background steps
                        if (backgroundSteps != null) {
                            for (backgroundStep in backgroundSteps) {
                                var newbackgroundStep:Step = new Step(backgroundStep.location,
                                                                      backgroundStep.keyword,
                                                                      backgroundStep.text,
                                                                      backgroundStep.argument);
                                newScenarioSteps.push(backgroundStep);
                            }
                        }

                        // copy and expand outline steps
                        for (step in scenarioOutline.steps) {
                            var newStepText:String = step.text;
                            var n:Int = 0;
                            for (headerCell in header.cells) {
                                var headerCellValue:String = headerCell.value;
                                var cellValue:String = row.cells[n].value;
                                n++;
                                newStepText = StringTools.replace(newStepText, "<" + headerCellValue + ">", cellValue);
                            }

                            var dataTable:DataTable = cast step.argument;
                            var newDataTable:DataTable = null;
                            if (dataTable != null) {
                                var newDataTableRows:Array<TableRow> = new Array<TableRow>();
                                for (dataTableRow in dataTable.rows) {
                                    var newDataTableCells:Array<TableCell> = new Array<TableCell>();
                                    for (dataTableCell in dataTableRow.cells) {
                                        var dataTableCellValue = dataTableCell.value;

                                        var n = 0;
                                        for (headerCell in header.cells) {
                                            var headerCellValue:String = headerCell.value;
                                            var cellValue:String = row.cells[n].value;
                                            n++;

                                            dataTableCellValue = StringTools.replace(dataTableCellValue, "<" + headerCellValue + ">", cellValue);
                                        }

                                        var newDataTableCell:TableCell = new TableCell(dataTableCell.location, dataTableCellValue);
                                        newDataTableCells.push(newDataTableCell);
                                    }
                                    var newDataTableRow = new TableRow(dataTableRow.location, newDataTableCells);
                                    newDataTableRows.push(newDataTableRow);
                                }
                                newDataTable = new DataTable(newDataTableRows);
                            }

                            var newStep:Step = null;
                            if (newDataTable == null) {
                                newStep = new Step(step.location, step.keyword, newStepText, step.argument);
                            } else {
                                newStep = new Step(step.location, step.keyword, newStepText, newDataTable);
                            }

                            newScenarioSteps.push(newStep);
                        }

                        var newScenario:Scenario = new Scenario(scenarioOutline.tags,
                                                                scenarioOutline.location,
                                                                scenarioOutline.keyword,
                                                                scenarioOutline.name,
                                                                scenarioOutline.description,
                                                                newScenarioSteps);
                        newScenario.addTags(doc.feature.tags);
                        newChildren.push(newScenario);
                    }
                }
            } else if (Std.is(child, Scenario)) {
                var scenario:Scenario = cast child;
                var newScenarioSteps:Array<Step> = new Array<Step>();
                // copy background steps
                if (backgroundSteps != null) {
                    for (backgroundStep in backgroundSteps) {
                        var newbackgroundStep:Step = new Step(backgroundStep.location,
                                                              backgroundStep.keyword,
                                                              backgroundStep.text,
                                                              backgroundStep.argument);
                        newScenarioSteps.push(backgroundStep);
                    }
                }

                // copy scenario steps
                for (step in scenario.steps) {
                    var newStep:Step = new Step(step.location, step.keyword, step.text, step.argument);
                    newScenarioSteps.push(newStep);
                }

                var newScenario:Scenario = new Scenario(scenario.tags,
                                                        scenario.location,
                                                        scenario.keyword,
                                                        scenario.name,
                                                        scenario.description,
                                                        newScenarioSteps);
                newScenario.addTags(doc.feature.tags);
                newChildren.push(newScenario);
            }
        }

        var feature:Feature = new Feature(doc.feature.tags,
                                          doc.feature.location,
                                          doc.feature.language,
                                          doc.feature.keyword,
                                          doc.feature.name,
                                          doc.feature.description,
                                          newChildren);

        expandedDoc = new GherkinDocument(feature, doc.comments);
        return expandedDoc;
    }

}