import _ from "lodash"
import { Errors } from "./errors"

export class BlockDependecines {
  constructor(block, structure) {
    this.block = block
    this.structure = structure || []
    this._isImplicit = (structure === null || structure === undefined)
    this.names = _.cloneDeep(this.structure)
    if (!Array.isArray(this.names)) {
      this.names = []
    }
    this.errors = new Errors()
  }

  isImplicit() {
    return this._isImplicit
  }

  validate() {
    if (!Array.isArray(this.names)) {
      this.errors.add("names", "BlockDependecines: must be an array")
    }
  }

  updateDependencyName(oldName, newName) {
    this.names = this.names.map((name) => {
      if(name === oldName) {
        return newName
      } else {
        return name
      }
    })

    this.names.sort()
    this.names = _.sortedUniq(this.names)
  }

  listNames() {
    if(this.isImplicit()) {
      let index = this.block.pipeline.blocks.findIndex((b) => {
        return b.uid === this.block.uid
      })

      if(index === 0 || index === -1) {
        return []
      } else {
        return [this.block.pipeline.blocks[index-1].name]
      }
    } else {
      return this.names
        .map((name) => this.block.pipeline.findBlockByName(name))
        .filter((b) => b !== null)
        .map((b) => b.name)
    }
  }

  listBlockUids() {
    if(this.isImplicit()) {
      let index = this.block.pipeline.blocks.findIndex((b) => {
        return b.uid === this.block.uid
      })

      if(index === 0) {
        return []
      } else {
        return [this.block.pipeline.blocks[index-1].uid]
      }
    } else {
      return this.names
        .map((name) => this.block.pipeline.findBlockByName(name))
        .filter((b) => b !== null)
        .map((b) => b.uid)
    }
  }

  convertToExplicit() {
    if(this.isImplicit()) {
      this.names = this.listNames()
      this._isImplicit = false
    }
  }

  add(name) {
    this.block.pipeline.blocks.forEach((b) => b.dependencies.convertToExplicit())

    this.names.push(name)

    this.names.sort()
    this.names = _.sortedUniq(this.names)

    this.afterUpdate()
  }

  remove(name) {
    this.block.pipeline.blocks.forEach((b) => b.dependencies.convertToExplicit())

    this.names = this.names.filter(d => d !== name)

    this.afterUpdate()
  }

  includes(name) {
    return this.listNames().includes(name)
  }

  afterUpdate() {
    this.block.afterUpdate()
  }

  toJson() {
    return this.listNames()
  }

}
