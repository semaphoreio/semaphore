import _ from "lodash"

import { SelectionRegister } from "../selection_register"
import { Features } from "../../features"
import { Errors } from "./errors"

export class AutoPromote {
  constructor(promotion, structure) {
    this.parent = promotion
    this.structure = structure || {}

    this.condition = this.structure.when
    this.parameters = this.structure.parameters || []

    this.errors = new Errors()
  }

  validate() {
    this.errors.reset()

    if(this.isEnabled() && this.condition === "") {
      this.errors.add("condition", "When condition can't be empty.")
    }
  }

  isEnabled() {
    return !this.isDisabled()
  }

  isDisabled() {
    return this.condition === undefined || this.condition === null
  }

  toggle() {
    if(this.isEnabled()) {
      this.disable()
    } else {
      this.enable()
    }
  }

  enable() {
    this.condition = "branch = 'master' AND result = 'passed'"

    this.parent.afterUpdate()
  }

  disable() {
    this.condition = null

    this.parent.afterUpdate()
  }

  setCondition(condition) {
    this.condition = condition

    this.parent.afterUpdate()
  }

  toJson() {
    let res = _.cloneDeep(this.structure)

    res["when"] = this.condition

    return res
  }
}

class Parameters {
  constructor(promotion, parameters) {
    this.promotion = promotion
    this.parameters = (parameters || {})["env_vars"] || []
  }

  exists() {
    return this.parameters.length !== 0
  }

  map(cb) {
    return this.parameters.map(cb)
  }

  add() {
    this.parameters.push({
      required: true,
      options: [],
      default_value: "",
      description: "",
      name: "",
    })
    this.promotion.afterUpdate()
  }

  changeName(index, name) {
    this.parameters[index].name = name
    this.promotion.afterUpdate()
  }

  changeDescription(index, val) {
    this.parameters[index].description = val
    this.promotion.afterUpdate()
  }

  changeDefault(index, val) {
    this.parameters[index].default_value = val
    this.promotion.afterUpdate()
  }

  changeOptions(index, options) {
    this.parameters[index].options = options
    this.promotion.afterUpdate()
  }

  changeRequired(index, val) {
    this.parameters[index].required = val
    this.promotion.afterUpdate()
  }

  remove(index) {
    this.parameters.splice(index, 1)
    this.promotion.afterUpdate()
  }

  toJson() {
    let res = {}

    res["env_vars"] = this.parameters

    return res
  }
}

export class Promotion {
  static setValidDeploymentTargets(deploymentTargets) {
    this._validDeploymentTargets = deploymentTargets
  }

  static setProjectName(projectName) {
    this._projectName = projectName
  }

  static validDeploymentTargets() {
    return this._validDeploymentTargets || []
  }

  static getProjectName() {
    return this._projectName
  }

  constructor(pipeline, structure) {
    this.modelName = "promotion"
    this.structure = structure
    this.uid = SelectionRegister.add(this)

    this.pipeline = pipeline
    this.structure = structure || {}
    this.targetPipelineFile = this.structure["pipeline_file"]

    this.name = this.structure.name || ""
    this.deploymentTarget = this.structure["deployment_target"] || ""

    this.autoPromote = new AutoPromote(this, this.structure["auto_promote"])
    this.parameters = new Parameters(this, this.structure["parameters"])

    this.errors = new Errors()
  }

  validate() {
    this.errors.reset()

    if (!Promotion.validDeploymentTargets().includes(this.deploymentTarget) && this.deploymentTarget !== "") {
      this.errors.add("deployment_target",
        `Deployment target "${this.deploymentTarget}" is not available for this project`)
    }

    this.autoPromote.validate()

    if(this.autoPromote.errors.exists()) {
      this.errors.addNested(`Auto Promotion`, this.autoPromote.errors)
    }
  }

  isAutomatic() {
    return this.autoPromote.isEnabled()
  }

  changeName(name) {
    this.name = name
    this.afterUpdate()
  }

  changeDeploymentTarget(deploymentTarget) {
    this.deploymentTarget = deploymentTarget
    this.afterUpdate()
  }

  targetPipeline() {
    return this.pipeline.workflow.findPipelineByPath(this.targetPipelineFilename())
  }

  targetPipelineFilename() {
    if (this.targetPipelineFile.startsWith("/")) {
      return this.targetPipelineFile.substring(1)
    }

    let pathElements = this.pipeline.filePath.split("/")
    pathElements[pathElements.length - 1] = this.targetPipelineFile
    return pathElements.join("/")
  }

  toJson() {
    let res = _.cloneDeep(this.structure)

    if(this.name) {
      res["name"] = this.name
    } else {
      delete res["name"]
    }

    if (Features.isEnabled("deploymentTargets") && this.deploymentTarget) {
      res["deployment_target"] = this.deploymentTarget
    } else {
      delete res["deployment_target"]
    }

    if(this.targetPipelineFile) {
      res["pipeline_file"] = this.targetPipelineFile
    } else {
      delete res["name"]
    }

    if(this.autoPromote.isEnabled()) {
      res["auto_promote"] = this.autoPromote.toJson()
    } else {
      delete res["auto_promote"]
    }

    if(this.parameters.exists()) {
      res["parameters"] = this.parameters.toJson()
    } else {
      delete res["parameters"]
    }

    return res
  }

  afterUpdate() {
    this.pipeline.afterUpdate()
  }
}
