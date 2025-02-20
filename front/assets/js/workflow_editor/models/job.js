import _ from "lodash"
import { Errors } from "./errors"

export class Job {
  constructor(block, index, structure) {
    this.modelName = "job"
    this.structure = structure

    this.block = block;
    this.name = this.structure.name || `Nameless ${index + 1}`
    this.commands = this.structure.commands || []
    this.parallelism = this.structure.parallelism || null
    this.matrix = this.structure.matrix || null

    this.errors = new Errors()
  }

  validate() {
    this.errors.reset()

    if(this.parallelism !== null && this.parallelism < 1) {
      this.errors.add("parallelism", "Parallelism must be larger than 0")
    }
  }

  parallelismCount() {
    return this.parallelism
  }

  hasParallelismEnabled() {
    return this.parallelism !== null
  }

  hasMatrixEnabled() {
    return this.matrix !== null
  }

  disableMatrix() {
    this.matrix = null

    this.afterUpdate()
  }

  disableParallelism() {
    this.parallelism = null

    this.afterUpdate()
  }

  changeMatrix(config) {
    this.matrix = config

    this.afterUpdate()
  }

  addMatrixEnv(name, values) {
    this.matrix.push({env_var: name, values: values})

    this.afterUpdate()
  }

  removeMatrixEnvVar(index) {
    this.matrix.splice(index, 1)
    this.afterUpdate()
  }

  changeMatrixEnvVarName(index, newName) {
    this.matrix[index].env_var = newName
    this.afterUpdate()
  }

  changeMatrixEnvVarValues(index, newValues) {
    this.matrix[index].values = newValues
    this.afterUpdate()
  }

  changeName(name) {
    this.name = name

    this.afterUpdate()
  }

  changeCommands(commands) {
    this.commands = commands

    this.afterUpdate()
  }

  changeParallelism(newValue) {
    this.parallelism = newValue

    this.afterUpdate()
  }

  afterUpdate() {
    this.block.afterUpdate()
  }

  toJson() {
    let res = _.cloneDeep(this.structure)

    res["name"] = this.name
    res["commands"] = this.commands

    if(this.parallelism) {
      res["parallelism"] = this.parallelism
    } else {
      delete res.parallelism
    }

    if(this.matrix) {
      res["matrix"] = this.matrix
    } else {
      delete res.matrix
    }

    return res
  }
}
