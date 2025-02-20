import _ from "lodash"

import { Container } from "./container"

export class Agent {
  // injected when the Editor app starts
  static setValidAgentTypes(agentTypes) {
    this._validAgentTypes = agentTypes
  }

  static setupTestNoAgentTypes() {
    Agent.setValidAgentTypes({
      agent_types: []
    })
  }

  static setupTestAgentTypes() {
    Agent.setValidAgentTypes({
      agent_types: [
        {
          type: "e1-standard-2",
          spec: "2 vCPU, 4 GB ram",
          os_image: "ubuntu1804",
          platform: "LINUX"
        },
        {
          type: "e1-standard-2",
          spec: "2 vCPU, 4 GB ram",
          os_image: "ubuntu2004",
          platform: "LINUX"
        },
        {
          type: "e1-standard-4",
          spec: "4 vCPU, 8 GB ram",
          os_image: "ubuntu1804",
          platform: "LINUX"
        },
        {
          type: "e1-standard-4",
          spec: "4 vCPU, 8 GB ram",
          os_image: "ubuntu2004",
          platform: "LINUX"
        },
        {
          type: "e1-standard-8",
          spec: "8 vCPU, 16 GB ram",
          os_image: "ubuntu1804",
          platform: "LINUX"
        },
        {
          type: "e1-standard-8",
          spec: "8 vCPU, 16 GB ram",
          os_image: "ubuntu2004",
          platform: "LINUX"
        },
        {
          type: "a1-standard-4",
          spec: "4 vCPU, 8 GB ram",
          os_image: "macos-xcode11",
          platform: "MAC"
        },
        {
          type: "a1-standard-4",
          spec: "4 vCPU, 8 GB ram",
          os_image: "macos-xcode12",
          platform: "MAC"
        },
        {
          type: "a1-standard-4",
          spec: "4 vCPU, 8 GB ram",
          os_image: "macos-xcode13",
          platform: "MAC"
        },
        {
          type: "s1-linux",
          spec: "",
          os_image: "",
          platform: "SELF_HOSTED"
        },
        {
          type: "s1-aws",
          spec: "",
          os_image: "",
          platform: "SELF_HOSTED"
        }
      ],
      default_linux_os_image: "ubuntu2004",
      default_mac_os_image: "macos-xcode13"
    })
  }

  static get ENVIRONMENT_TYPE_DOCKER()      { return "docker";   }
  static get ENVIRONMENT_TYPE_LINUX_VM()    { return "linux-vm"; }
  static get ENVIRONMENT_TYPE_MAC_VM()      { return "mac-vm";   }
  static get ENVIRONMENT_TYPE_SELF_HOSTED() { return "self-hosted" }
  static get ENVIRONMENT_TYPE_UNAVAILABLE() { return "unavailable" }
  static get ENVIRONMENT_TYPE_UNKNOWN()     { return "unknown" }

  static get ENVIRONMENT_TYPES() {
    return [
      Agent.ENVIRONMENT_TYPE_DOCKER,
      Agent.ENVIRONMENT_TYPE_LINUX_VM,
      Agent.ENVIRONMENT_TYPE_MAC_VM,
      Agent.ENVIRONMENT_TYPE_SELF_HOSTED,
      Agent.ENVIRONMENT_TYPE_UNAVAILABLE,
      Agent.ENVIRONMENT_TYPE_UNKNOWN
    ]
  }

  constructor(parent, structure) {
    this.parent = parent // this can be pipeline of block
    this.structure = structure || {}

    let machine = this.structure.machine || {}

    this.type = machine.type || this.defaultMachineType()
    this.osImage = machine.os_image || this.defaultOSImage(this.type)

    this.containers = (this.structure.containers || []).map((c) => {
      return new Container(this, c)
    })
  }

  environmentType() {
    if (this.allMachineTypes().length == 0) {
      return Agent.ENVIRONMENT_TYPE_UNAVAILABLE
    }

    if (this.containers.length > 0) {
      return Agent.ENVIRONMENT_TYPE_DOCKER
    }

    if (_.includes(this.availableMachineTypes("LINUX"), this.type)) {
      return Agent.ENVIRONMENT_TYPE_LINUX_VM
    }

    if (_.includes(this.availableMachineTypes("MAC"), this.type)) {
      return Agent.ENVIRONMENT_TYPE_MAC_VM
    }

    if (_.includes(this.availableMachineTypes("SELF_HOSTED"), this.type)) {
      return Agent.ENVIRONMENT_TYPE_SELF_HOSTED
    }

    return Agent.ENVIRONMENT_TYPE_UNKNOWN
  }

  changeEnvironmentType(newType) {
    if(!Agent.ENVIRONMENT_TYPES.includes(newType)) {
      throw `Attempted to change agent to unknown environment type ${newType}`
    }

    switch(newType) {
      case Agent.ENVIRONMENT_TYPE_LINUX_VM:
        this.type = "e1-standard-2"
        this.osImage = this.defaultOSImage(this.type)
        this.containers = []
        break

      case Agent.ENVIRONMENT_TYPE_MAC_VM:
        this.type = "a1-standard-4"
        this.osImage = this.defaultOSImage(this.type)
        this.containers = []
        break

      case Agent.ENVIRONMENT_TYPE_DOCKER:
        this.type = "e1-standard-2"
        this.osImage = this.defaultOSImage(this.type)
        this.containers = [
          new Container(this, {
            "name": "main",
            "image": "semaphoreci/ubuntu:20.04"
          })
        ]
        break
      case Agent.ENVIRONMENT_TYPE_SELF_HOSTED:
        this.type = this.availableMachineTypes("SELF_HOSTED")[0]
        this.osImage = ""
        this.containers = []
    }

    this.afterUpdate()
  }

  defaultMachineType() {
    if (_.includes(this.availableMachineTypes("LINUX"), "e1-standard-2")) {
      return "e1-standard-2"
    }

    return ""
  }

  defaultOSImage(type) {
    if (_.includes(this.availableMachineTypes("MAC"), type)) {
      return Agent._validAgentTypes.default_mac_os_image
    }

    if (_.includes(this.availableMachineTypes("LINUX"), type)) {
      return Agent._validAgentTypes.default_linux_os_image
    }

    return ""
  }

  availableOSImages(type) {
    if (this.isSelfHostedType(type)) {
      return []
    }

    return _.uniq(Agent._validAgentTypes.agent_types.filter(at => at.type === type).map(at => at.os_image))
  }

  availableMachineTypes(platform) {
    return _.uniq(this.agentTypes(platform).map(at => at.type))
  }

  allMachineTypes() {
    return _.uniq(Agent._validAgentTypes.agent_types.map(at => at.type))
  }

  zeroStateMachineTypes() {
    return _.uniq(Agent._validAgentTypes.agent_types.filter(at => at.state === "ZERO_STATE").map(at => at.type))
  }

  specs(type) {
    return Agent._validAgentTypes.agent_types.filter(at => at.type === type)[0].specs
  }

  agentTypes(platform) {
    return Agent._validAgentTypes.agent_types.filter(at => at.platform === platform)
  }

  changeMachineType(type) {
    this.type = type

    // When new type is not a self-hosted one, select default os image when
    // there are none available for this type
    if(!_.includes(this.availableOSImages(type), this.osImage) && !this.isSelfHostedType(type)) {
      this.osImage = this.defaultOSImage(type)
    }

    this.afterUpdate()
  }

  changeOSImage(image) {
    this.osImage = image

    this.afterUpdate()
  }

  addNewContainer() {
    let containerName = ""

    if(this.containers.length === 0) {
      containerName = "main"
    } else {
      containerName = "c" + (this.containers.length + 1)
    }

    let c = new Container(this, {name: containerName})
    this.containers.push(c)
    this.afterUpdate()
  }

  removeContainerByIndex(index) {
    this.containers.splice(index, 1)
    this.afterUpdate()
  }

  toJson() {
    let res = _.cloneDeep(this.structure)

    res["machine"] = res["machine"] || {}
    res["machine"]["type"] = this.type
    res["machine"]["os_image"] = this.osImage

    if(this.containers.length > 0) {
      res["containers"] = this.containers.map((c) => c.toJson())
    } else {
      delete res.containers
    }

    return res
  }

  afterUpdate() {
    this.parent.afterUpdate()
  }

  isSelfHostedType(type) {
    return _.includes(this.availableMachineTypes("SELF_HOSTED"), type)
  }

  isInvalidImage(type) {
    return !_.includes(this.availableOSImages(type), this.osImage)
  }

  isInvalidMachineType(type) {
    return !_.includes(this.allMachineTypes(), type)
  }

  isZeroState(type) {
    return _.includes(this.zeroStateMachineTypes(), type)
  }
}
