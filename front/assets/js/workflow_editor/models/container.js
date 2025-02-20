import _ from "lodash"

import { EnvVars } from "./env_vars"

export class Container {
  constructor(agent, structure) {
    this.agent = agent
    this.structure = structure || {}

    this.name = this.structure.name || ""
    this.image = this.structure.image || ""
    this.envVars = new EnvVars(this, this.structure.env_vars)
  }

  changeName(name) {
    this.name = name
    this.afterUpdate()
  }

  changeImage(image) {
    this.image = image
    this.afterUpdate()
  }

  toJson() {
    let res = _.cloneDeep(this.structure)

    res["name"] = this.name
    res["image"] = this.image

    if(!this.envVars.isEmpty()) {
      res["env_vars"] = this.envVars.toJson()
    } else {
      delete res["env_vars"]
    }

    return res
  }

  afterUpdate() {
    this.agent.afterUpdate()
  }
}
