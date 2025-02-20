import _ from "lodash"

export class GlobalJobConfig {
  constructor(parent, structure) {
    this.parent = parent
    this.structure = structure || {}

    this.prologue       = _.get(this.structure, ["prologue", "commands"]) || []
    this.epilogueAlways = _.get(this.structure, ["epilogue", "always", "commands"]) || []
    this.epilogueOnFail = _.get(this.structure, ["epilogue", "on_fail", "commands"]) || []
    this.epilogueOnPass = _.get(this.structure, ["epilogue", "on_pass", "commands"]) || []
  }

  prologueCommands()       { return this.prologue }
  epilogueOnPassCommands() { return this.epilogueOnPass }
  epilogueOnFailCommands() { return this.epilogueOnFail }
  epilogueAlwaysCommands() { return this.epilogueAlways }

  changePrologue(commands)       { this.prologue = commands; this.parent.afterUpdate(); }
  changeEpilogueOnPass(commands) { this.epilogueOnPass = commands; this.parent.afterUpdate(); }
  changeEpilogueOnFail(commands) { this.epilogueOnFail = commands; this.parent.afterUpdate(); }
  changeEpilogueAlways(commands) { this.epilogueAlways = commands; this.parent.afterUpdate(); }

  hasEpilogue() {
    return this.epilogueAlways.length > 0 ||
      this.epilogueOnPass.length > 0 ||
      this.epilogueOnFail.length > 0;
  }

  toJson() {
    let res = _.cloneDeep(this.structure)

    if(this.prologue.length > 0) {
      res["prologue"] = {}
      res["prologue"]["commands"] = this.prologue
    } else {
      delete res.prologue
    }

    if(this.hasEpilogue()) {
      res.epilogue = {}
    } else {
      delete res.epilogue
    }

    if(this.epilogueAlways.length > 0) {
      res.epilogue.always = {
        "commands": this.epilogueAlways
      }
    }

    if(this.epilogueOnPass.length > 0) {
      res.epilogue.on_pass = {
        "commands": this.epilogueOnPass
      }
    }

    if(this.epilogueOnFail.length > 0) {
      res.epilogue.on_fail = {
        "commands": this.epilogueOnFail
      }
    }

    return res
  }
}
