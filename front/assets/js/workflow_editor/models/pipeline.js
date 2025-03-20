import _ from "lodash"
import yaml from "js-yaml"
import schemaValidator from "./pipeline_schema_validator"

import { Agent } from "./agent"
import { Block } from "./block"
import { Promotion } from "./promotion"
import { AfterPipeline } from "./after_pipeline"

import { GlobalJobConfig } from "./global_job_config"
import { ExecutionTimeLimit } from "./execution_time_limit"
import { FailFast } from "./fail_fast"
import { AutoCancel } from "./auto_cancel"
import { Errors } from "./errors"

import { SelectionRegister } from "../selection_register"
import { LineEndings } from "../line_endings"
import { Paths } from "../paths"

export class Pipeline {
  static fromYaml(workflow, yamlContent, path, createdInEditor) {
    let pipeline = new Pipeline(workflow, yamlContent, path, createdInEditor)

    return pipeline
  }

  constructor(workflow, yamlContent, path, createdInEditor) {
    //
    // Saving the initial values for the path and content. In case the user
    // renames the file or changes the content, we can always look up the
    // original values.
    //
    this.initialYaml = yamlContent
    this.initialFilePath = path
    this.createdInEditor = !!createdInEditor
    this.schemaErrors = []

    //
    // The line ending of the initialYAML is used while generating new YAML(s)
    //
    // We give our best to keep the users choice based on the dominant line
    // endings in the original file.
    //
    this.lineEndingInInitialYaml = LineEndings.dominantLineEnding(yamlContent)

    this.modelName = "pipeline"
    this.uid = SelectionRegister.add(this)

    this.errors = new Errors()
    this.workflow = workflow

    this.filePath = path
    this.updateYaml(yamlContent)
  }

  updateYaml(yamlContent) {
    this.yaml = yamlContent
    this.yamlError = null
    this.errors.reset()

    try {
      this.structure = yaml.safeLoad(yamlContent)

      this.name = this.structure.name || ""
      this.blocks = (this.structure.blocks || []).map(b => new Block(this, b))
      this.agent = new Agent(this, this.structure.agent)
      this.executionTimeLimit = new ExecutionTimeLimit(this, this.structure.execution_time_limit)
      this.promotions = (this.structure.promotions || []).map(p => new Promotion(this, p))
      this.failFast = new FailFast(this, this.structure.fail_fast)
      this.autoCancel = new AutoCancel(this, this.structure.auto_cancel)
      this.globalJobConfig = new GlobalJobConfig(this, this.structure.global_job_config)
      this.afterPipeline = new AfterPipeline(this, this.structure["after_pipeline"])
    } catch(e) {
      if(e instanceof yaml.YAMLException) {
        this.structure = {}
        this.yamlError = e
      } else {
        // unknown exception, bubble it up furhter
        throw e
      }
    }

    this.afterUpdate()
  }

  changeFilePath(newPath) {
    if(this.workflow.initialYAMLPath === this.filePath) {
      throw "Can't change path of initial pipeline"
    }

    this.workflow.pipelines.forEach((p) => {
      p.promotions.forEach((promotion) => {
        if(promotion.targetPipeline().filePath === this.filePath) {
          promotion.targetPipelineFile = Paths.relative(p.filePath, newPath)
        }
      })
    })

    this.filePath = newPath

    this.afterUpdate()
  }

  isPathChangedFromInitial() {
    return this.filePath !== this.initialFilePath
  }

  hasInvalidYaml() {
    return this.yamlError !== null
  }

  hasSchemaErrors() {
    return this.schemaErrors.length > 0;
  }

  validate() {
    if(this.hasInvalidYaml()) {
      return
    }

    this.errors.reset()
    this.blocks.forEach((b) => b.validate())
    this.promotions.forEach((p) => p.validate())

    if(this.name === "") {
      this.errors.add("name", "Pipeline name can't be blank.")
    }

    this.validateSchema()
  }

  validateSchema() {
    this.schemaErrors = []

    const valid = schemaValidator(this.structure)

    if (!valid) {
      const errors = schemaValidator.errors;
      let yamlString = ""
      try {
        yamlString = yaml.safeDump(this.structure);
      } catch (error) {
        return;
      }
      const yamlLines = yamlString.split("\n");

      this.schemaErrors = errors
        .map(err => {
          const location = this.findLineColumn(err.instancePath, err.params, yamlLines);
          if (!location) return null;
          return { ...err, line: location.line, column: location.column };
        })
        .filter(e => e);
    }
  }

  findLineColumn(instancePath, wrongParams, yamlLines) {
    const keys = instancePath.split("/").filter(Boolean);
    const isMissingKey = !!wrongParams.missingProperty;
    const wrongParam = isMissingKey ? wrongParams.missingProperty : wrongParams.additionalProperty;
    let depth = 0;
    let foundLastKey = false;

    if (isMissingKey && instancePath === '') {
      return { line: -1, column: -1 };
    }
  
    for (let i = 0; i < yamlLines.length; i++) {
      const line = yamlLines[i];
      const trimmed = line.trim();
      const key = keys[depth];
      const indentSize = line.length - trimmed.length;
      const isNumericKey = Number.isInteger(Number(key));
      const isListKey = isNumericKey && line.startsWith(" ".repeat(indentSize) + "-");
      
      if (trimmed.startsWith(`${key}:`) || isListKey) {
        depth++;
        if (depth >= keys.length - 1) {
          foundLastKey = true;
          if (isMissingKey) return { line: i + 1, column: line.indexOf(key) + 1 };
        }
      }
  
      if ((foundLastKey || keys.length === 0) &&
          (trimmed.startsWith(`${wrongParam}:`) || trimmed.startsWith(`- ${wrongParam}:`))) {
        return { line: i + 1, column: line.indexOf(wrongParam) + 1 };
      }
  
      if (depth >= keys.length + 1) break;
    }
  
    return null;
  }

  createNewBlock() {
    let blockParams = {}

    blockParams["name"] = "Block #" + (this.blocks.length + 1)

    if(!this.hasImplicitDependencies()) {
      let selected = SelectionRegister.getSelectedElement()

      if(selected && selected.modelName === "block") {
        blockParams["dependencies"] = [selected.name]
      } else {
        blockParams["dependencies"] = []
      }
    }

    let b = new Block(this, blockParams)

    b.addJob({name: "Job #1", commands: []})

    this.blocks.push(b)
    this.afterUpdate()

    return b
  }

  prologueCommands() {
    return this.globalJobConfig.prologueCommands()
  }

  epilogueOnPassCommands() {
    return this.globalJobConfig.epilogueOnPassCommands()
  }

  epilogueOnFailCommands() {
    return this.globalJobConfig.epilogueOnFailCommands()
  }

  epilogueAlwaysCommands() {
    return this.globalJobConfig.epilogueAlwaysCommands()
  }

  changePrologue(commands) {
    this.globalJobConfig.changePrologue(commands)
  }

  changeEpilogueOnPass(commands) {
    this.globalJobConfig.changeEpilogueOnPass(commands)
  }

  changeEpilogueOnFail(commands) {
    this.globalJobConfig.changeEpilogueOnFail(commands)
  }

  changeEpilogueAlways(commands) {
    this.globalJobConfig.changeEpilogueAlways(commands)
  }

  addPromotion() {
    let promotionsIndex = this.promotions.length + 1
    let name  = `Promotion ${promotionsIndex}`

    let pipelineIndex = this.workflow.pipelines.length + 1
    let path  = `pipeline_${pipelineIndex}.yml`

    let promotion = new Promotion(this, {
      name: name,
      pipeline_file: path
    })

    this.promotions.push(promotion)

    this.workflow.addPipeline(".semaphore/" + path)

    this.afterUpdate()

    return promotion
  }

  hasImplicitDependencies() {
    return this.blocks.some((b) => b.dependencies.isImplicit())
  }

  changeName(newName) {
    this.name = newName

    this.afterUpdate()
  }

  removeBlock(block) {
    let index = this.blocks.findIndex((b) => b == block)

    if(index < 0) { throw 'Block not found in pipeline'; }

    // remove the current block from the pipeline's list
    this.blocks.splice(index, 1)

    this.afterUpdate()
  }

  removePromotion(promotion) {
    let index = this.promotions.findIndex((p) => p === promotion)

    if(index < 0) { throw 'Promotion not found in pipeline'; }

    this.promotions.splice(index, 1)

    let targetPipeline = promotion.targetPipeline()

    if(targetPipeline) {
      this.workflow.expanded.collapse(promotion)
      this.workflow.deletePipeline(targetPipeline)
    }

    this.afterUpdate()
  }

  findBlockByName(blockName) {
    return this.blocks.find((b) => b.name === blockName) || null
  }

  afterUpdate() {
    this.workflow.afterUpdate()
  }

  toJson() {
    let res = _.clone(this.structure)

    res["version"] = "v1.0"
    res["name"] = this.name
    res["agent"] = this.agent.toJson()

    if(!_.isEqual(this.globalJobConfig.toJson(), {})) {
      res["global_job_config"] = this.globalJobConfig.toJson()
    } else {
      delete res.global_job_config
    }

    if(this.executionTimeLimit.isDefined()) {
      res["execution_time_limit"] = this.executionTimeLimit.toJson()
    } else {
      delete res.execution_time_limit
    }

    if(this.failFast.isDefined()) {
      res["fail_fast"] = this.failFast.toJson()
    } else {
      delete res.fail_fast
    }

    if(this.autoCancel.isDefined()) {
      res["auto_cancel"] = this.autoCancel.toJson()
    } else {
      delete res.auto_cancel
    }

    res["blocks"] = this.blocks.map((b) => b.toJson())

    if(this.promotions.length > 0) {
      res["promotions"] = this.promotions.map(p => p.toJson())
    } else {
      delete res.promotions
    }

    if(this.afterPipeline.isDefined()) {
      res["after_pipeline"] = this.afterPipeline.toJson()
    } else {
      delete res.after_pipeline
    }

    return this.preferedKeyOrder(res, {
      version: 1,
      name: 2,
      agent: 3,
      __other__: 4,
      global_job_config: 97,
      blocks: 98,
      after_pipeline: 99,
      promotions: 100
    })
  }

  //
  // In Javascript, you can't really define the key order. ES6 did introduce
  // some restrictions, but mathematically strict key order is still not
  // possible.
  //
  // In practice however the insertion order is the one that defines the
  // order. This is especially true for objects with low number of keys.
  //
  preferedKeyOrder(res, keyPreferences) {
    let __other__ = keyPreferences["__other__"] || 1000

    let orderedPairs = _(res).toPairs().sortBy((e) => {
      let key = e[0]
      let preferedPosition = keyPreferences[key] || __other__

      return preferedPosition
    })

    return orderedPairs.fromPairs().value()
  }

  hasCommitableChanges() {
    return this.createdInEditor || this.initialYaml !== this.toYaml()
  }

  toYaml() {
    let result = null

    if(this.hasInvalidYaml()) {
      result = this.yaml
    } else {
      try {
        result = yaml.safeDump(this.toJson(), {
          lineWidth: 500
        })
      } catch(e) {
        additionalInfoAboutYamlDumpError(e, this.toJson())

        throw e
      }
    }

    return LineEndings.enforceLineEnding(result, this.lineEndingInInitialYaml)
  }
}

function findUndefinedInJSON(json) {
  var path, i;

  if(Array.isArray(json)) {
    for(i = 0; i < json.length; i++) {
      path = findUndefinedInJSON(json[i])

      if(path !== null) {
        return `[${i}].${path}`
      }
    }
  }

  if(_.isObject(json)) {
    let keys = _.keys(json)

    for(i = 0; i < keys.length; i++) {
      path = findUndefinedInJSON(json[keys[i]])

      if(path !== null) {
        return `${keys[i]}.${path}`
      }
    }
  }

  if(json === undefined) {
    return "!"
  } else {
    return null
  }
}

function additionalInfoAboutYamlDumpError(e, json) {
  console.log("Failed to dump json into yaml")
  let path = findUndefinedInJSON(json)

  if(path) {
    console.log(path + " is undefined")
  }
}
