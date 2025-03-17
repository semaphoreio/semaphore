import _ from "lodash"

import { Pipeline }          from "./pipeline"
import { SelectionRegister } from "../selection_register"

export class Workflow {
  constructor(structure, schema = null) {
    this.modelName = "workflow"

    //
    // Expected structure:
    //
    // {
    //    initialYAML: String,
    //    createdInEditor: Bool,
    //    yamls: [
    //      {
    //        path: String,
    //        content: String,
    //      },
    //      ...
    //    ]
    // }
    //
    this.structure = structure
    this.schema = schema

    this.initialYAMLPath = structure.initialYAML

    this.pipelines = Object.keys(this.structure.yamls).map((path) => {
      let yaml = this.structure.yamls[path]

      return Pipeline.fromYaml(this, yaml, path, this.structure.createdInEditor, this.schema)
    })

    //
    // Keeps track of deleted pipelines that already existed in the commit.
    //
    this.deletedPipelines = []

    //
    // Keeps track of expanded promotions in the diagram.
    //
    this.expanded = new ExpandedPromotions(this)
  }

  deletedPipelineFilePaths() {
    let paths = this.deletedPipelines.filter((p) => {
      // maybe some pipeline started using the old path?

      return !this.pipelineWithPathExists(p.filePath)
    }).map((p) => {
      return p.filePath
    })

    //
    // Handle pipeline file path changes
    //
    let changedPaths = this.pipelines.filter((p) => {
      // sleect only pipelines that have changed the path

      return p.isPathChangedFromInitial()
    }).filter((p) => {
      // maybe some pipeline started using the old path?

      return !this.pipelineWithPathExists(p.initialFilePath)
    }).map((p) => {
      return p.initialFilePath
    })

    return _.uniq(paths.concat(changedPaths))
  }

  validate() {
    this.expanded.reccalibrate()

    this.pipelines.forEach((p) => p.validate())
  }

  toJson() {
    return this.pipelines.map((p) => p.toJson())
  }

  findPipelineByPath(path) {
    return this.pipelines.find(p => p.filePath === path)
  }

  pipelineWithPathExists(path) {
    return !!this.findPipelineByPath(path)
  }

  findInitialPipeline() {
    let init = this.findPipelineByPath(this.initialYAMLPath)

    if(!init) {
      throw new Error(`Initial pipeline ${this.initialYAMLPath} not found`)
    }

    return init
  }

  //
  // Pipelines sorted to feel natural to the customer.
  //
  // First, we have the initial pipeline, then the rest of them.
  //
  naturallySortedPipelines() {
    return this.pipelines.slice(0).sort((p1, p2) => {
      if(p1.filePath === this.initialYAMLPath) {
        return -1
      }

      if(p2.filePath === this.initialYAMLPath) {
        return 1
      }

      return p1.filePath < p2.filePath
    })
  }

  deletePipeline(pipeline) {
    if(this.initialYAMLPath === pipeline.filePath) {
      throw "Can't delete initial pipeline"
    }

    SelectionRegister.remove(pipeline.uid)

    pipeline.promotions.forEach((promotion) => {
      this.deletePipeline(promotion.targetPipeline())
    })

    this.pipelines.forEach((p) => {
      p.promotions.forEach((promotion) => {
        if(promotion.targetPipeline() === pipeline) {
          this.expanded.collapse(promotion)
          p.removePromotion(promotion)
        }
      })
    })

    let i = this.pipelines.findIndex(p => p === pipeline)

    if(i >= 0) {
      this.pipelines.splice(i, 1)
    }

    if(!pipeline.createdInEditor) {
      this.deletedPipelines.push(pipeline)
    }

    this.afterUpdate()
  }

  addPipeline(filePath) {
    let i = this.deletedPipelines.findIndex(p => p.filePath === filePath)
    if(i >= 0) {
      this.deletedPipelines.splice(i, 1)
    }

    let yaml = `
version: v1.0
name: Pipeline ${this.pipelines.length + 1}
blocks:
  - name: "Block #1"
    task:
      jobs:
        - name: "Job #1"
          commands:
            - echo "job 1"
`

    this.pipelines.push(Pipeline.fromYaml(this, yaml, filePath, true, this.schema))

    this.afterUpdate()
  }

  onUpdate(callback) {

    this.callback = callback
  }

  afterUpdate() {
    if(this.callback !== null && this.callback !== undefined) {
      this.callback()
    }
  }

  commitableChangeCount() {
    let changed = this.pipelines.filter((p) => p.hasCommitableChanges()).length
    let deleted = this.deletedPipelines.length

    return changed + deleted
  }

  hasCommitableChanges() {
    return this.commitableChangeCount() > 0
  }
}

class ExpandedPromotions {
  constructor(workflow) {
    this.workflow = workflow

    this.expandedPromotions = []
  }

  isExpanded(promotion) {
    let index = this.expandedPromotions.findIndex(p => p === promotion)

    return index >= 0
  }

  reccalibrate() {
    // If any of the pipelines have a YAML error, we are closing them

    let index = this.expandedPromotions.findIndex(p => {
      return p.pipeline.hasInvalidYaml()
    })

    if(index >= 0) {
      this.expandedPromotions.splice(index)
    }
  }

  pipelines() {
    let res = [this.workflow.findInitialPipeline()]

    this.expandedPromotions.forEach(p => {
      res.push(p.targetPipeline())
    })

    return res
  }

  expand(promotion) {
    //
    // If there is an already expanded promotion for the pipeline, collapse it.
    //

    let index = this.expandedPromotions.findIndex(p => {
      return p.pipeline === promotion.pipeline
    })
    if(index >= 0) {
      this.collapse(this.expandedPromotions[index])
    }

    this.expandedPromotions.push(promotion)

    this.workflow.afterUpdate()
  }

  collapse(promotion) {
    let index = this.expandedPromotions.findIndex(p => p === promotion)

    this.expandedPromotions.splice(index)

    this.workflow.afterUpdate()
  }
}
