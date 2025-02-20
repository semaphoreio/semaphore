import _ from "lodash"
import { Job } from "./job"
import { SelectionRegister } from "../selection_register"
import { DirectedGraph } from "../directed_graph"
import { BlockDependecines } from "./block_dependencies"
import { EnvVars } from "./env_vars"
import { Errors } from "./errors"
import { Secrets } from "./secrets"
import { Agent } from "./agent"

export class Block {
  constructor(pipeline, structure) {
    this.modelName = "block"
    this.uid = SelectionRegister.add(this)
    this.structure = structure

    this.dependencies = new BlockDependecines(this, this.structure.dependencies)
    this.pipeline = pipeline
    this.name = this.structure.name || ""
    this.jobs = (_.get(this.structure, ["task", "jobs"]) || []).map((j, i) => new Job(this, i, j));

    this.agent = new Agent(this, _.get(this.structure, ["task", "agent"]) || {})
    this.overrideGlobalAgent = _.has(this.structure, ["task", "agent"])

    this.prologue       = _.get(this.structure, ["task", "prologue", "commands"]) || []
    this.epilogueAlways = _.get(this.structure, ["task", "epilogue", "always", "commands"]) || []
    this.epilogueOnFail = _.get(this.structure, ["task", "epilogue", "on_fail", "commands"]) || []
    this.epilogueOnPass = _.get(this.structure, ["task", "epilogue", "on_pass", "commands"]) || []

    this.secrets = new Secrets(this, _.get(this.structure, ["task", "secrets"]) || [])
    this.envVars = new EnvVars(this, _.get(this.structure, ["task", "env_vars"]) || [])

    this.skipCondition = _.get(this.structure, ["skip", "when"]) || ""
    this.runCondition = _.get(this.structure, ["run", "when"]) || ""

    this.errors = new Errors()
  }

  validate() {
    this.errors.reset()
    this.secrets.validate()
    this.dependencies.validate()
    this.jobs.forEach(j => j.validate())

    if(this.name === "") {
      this.errors.add("name", "Block name can't be blank.")
    }

    if(this.pipeline.findBlockByName(this.name) !== this) {
      this.errors.add("name", "Name must be unique in pipeline.")
    }

    if(this.secrets.errors.exists()) {
      this.errors.addNested("secrets", this.secrets.errors)
    }

    this.jobs.forEach(j => {
      if(j.errors.exists()) {
        this.errors.addNested(`Job ${j.index}`, j.errors)
      }
    })

    if (this.dependencies.errors.exists()) {
      this.errors.addNested("dependencies", this.dependencies.errors)
    }
  }

  prologueCommands() {
    return this.prologue
  }

  epilogueOnPassCommands() { return this.epilogueOnPass }
  epilogueOnFailCommands() { return this.epilogueOnFail }
  epilogueAlwaysCommands() { return this.epilogueAlways }

  hasConditionForRunning() {
    return this.hasSkipConditions() || this.hasRunConditions()
  }

  hasSkipConditions() {
    return this.skipCondition !== null && this.skipCondition !== ""
  }

  hasRunConditions() {
    return this.runCondition !== null && this.runCondition !== ""
  }

  setSkipConditions(condition) {
    this.runCondition = ""
    this.skipCondition = condition
    this.afterUpdate()
  }

  setRunConditions(condition) {
    this.skipCondition = ""
    this.runCondition = condition
    this.afterUpdate()
  }

  clearConditionsForRunning() {
    this.runCondition = ""
    this.skipCondition = ""

    this.afterUpdate()
  }

  dependencyIntroducesCycle(otherBlock) {
    let g = new DirectedGraph()

    // first add all blocks as nodes
    this.pipeline.blocks.forEach((b) => g.addNode(b.name))

    // add all existing edges
    this.pipeline.blocks.forEach((b) => {
      b.dependencies.listNames().forEach((depName) => {
        g.addEdge(depName, b.name)
      })
    })

    // add the edge that we are testing
    g.addEdge(otherBlock.name, this.name)

    return g.hasCycle()
  }

  changeOverrideGlobalAgent(newValue) {
    this.overrideGlobalAgent = newValue

    this.afterUpdate()
  }

  changeName(newName) {
    let oldName = this.name

    this.pipeline.blocks.forEach((b) => {
      // we are basing this lookup on uids not on names
      // customers can enter duplicate names
      if(b.dependencies.listBlockUids().includes(this.uid)) {
        b.dependencies.updateDependencyName(oldName, newName)
      }
    })

    this.name = newName

    this.afterUpdate()
  }

  changeSkipCondition(condition) {
    this.skipCondition = condition

    this.afterUpdate()
  }

  changePrologue(commands) {
    this.prologue = commands

    this.afterUpdate()
  }

  changeEpilogueAlways(commands) {
    this.epilogueAlways = commands

    this.afterUpdate()
  }

  changeEpilogueOnFail(commands) {
    this.epilogueOnFail = commands

    this.afterUpdate()
  }

  changeEpilogueOnPass(commands) {
    this.epilogueOnPass = commands

    this.afterUpdate()
  }

  addJob(structure) {
    let j = new Job(this, this.jobs.length, structure)

    this.jobs.push(j)
    this.afterUpdate()

    return j
  }

  afterUpdate() {
    this.pipeline.afterUpdate()
  }

  hasEpilogue() {
    return this.epilogueAlways.length > 0 ||
      this.epilogueOnPass.length > 0 ||
      this.epilogueOnFail.length > 0;
  }

  hasPrologue() {
    return this.prologue.length > 0;
  }

  toJson() {
    let json = _.cloneDeep(this.structure)

    json.name = this.name

    if(this.skipCondition) {
      json.skip = {
        when: this.skipCondition
      }
    } else {
      delete json.skip
    }

    if(this.runCondition) {
      json.run = {
        when: this.runCondition
      }
    } else {
      delete json.run
    }

    if(!this.dependencies.isImplicit()) {
      try {
        json.dependencies = this.dependencies.toJson()
      } catch (e) {
        console.log("Error serializing dependencies of:", this.name, e)
      }
    } else {
      delete json.dependencies
    }

    json.task = json.task || {}

    if(!this.secrets.isEmpty()) {
      json.task.secrets = this.secrets.toJson()
    } else {
      delete json.task.secrets
    }

    if(!this.envVars.isEmpty()) {
      json.task.env_vars = this.envVars.toJson()
    } else {
      delete json.task.envVars
    }

    if(this.hasPrologue()) {
      json.task.prologue = {
        "commands": this.prologue
      }
    } else {
      delete json.task.prologue
    }

    if(this.hasEpilogue()) {
      json.task.epilogue = {}
    } else {
      delete json.task.epilogue
    }

    if(this.epilogueAlways.length > 0) {
      json.task.epilogue.always = {
        "commands": this.epilogueAlways
      }
    }

    if(this.epilogueOnPass.length > 0) {
      json.task.epilogue.on_pass = {
        "commands": this.epilogueOnPass
      }
    }

    if(this.epilogueOnFail.length > 0) {
      json.task.epilogue.on_fail = {
        "commands": this.epilogueOnFail
      }
    }

    if(this.overrideGlobalAgent) {
      json.task.agent = this.agent.toJson()
    } else {
      delete json.task.agent
    }

    json.task.jobs = this.jobs.map((j) => j.toJson())

    return json
  }

  remove() {
    SelectionRegister.remove(this.uid)
    this.pipeline.removeBlock(this)
  }

  removeJobByIndex(jobIndex) {
    this.jobs.splice(jobIndex, 1)
    this.afterUpdate()
  }
}
