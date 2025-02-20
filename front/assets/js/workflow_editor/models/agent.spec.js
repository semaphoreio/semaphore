import yaml from "js-yaml"

import { expect } from "chai"
import { Workflow } from "./workflow"
import { Agent } from "./agent"

describe("Agent", () => {
  let dummyParent = {
    afterUpdate: () => {}
  }

  describe("#availableOSImages", () => {
    Agent.setupTestAgentTypes();

    it("returns available OS images for agent type", () => {
      let agent = new Agent(dummyParent, {})

      expect(agent.availableOSImages("e1-standard-2")).to.eql(["ubuntu1804", "ubuntu2004"])
      expect(agent.availableOSImages("e1-standard-4")).to.eql(["ubuntu1804", "ubuntu2004"])
      expect(agent.availableOSImages("e1-standard-8")).to.eql(["ubuntu1804", "ubuntu2004"])
      expect(agent.availableOSImages("s1-linux")).to.eql([])
      expect(agent.availableOSImages("s1-aws")).to.eql([])
    })
  })

  describe("#constructor", () => {
    describe("when the machine type is defined", () => {
      let ppl = null;

      beforeEach(() => {
        Agent.setupTestAgentTypes();
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "agent": {
            "machine": {
              "type": "a1-standard-4",
              "os_image": "macos-xcode11"
            }
          },
          "blocks": []
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
      })

      it("sets type to the provided one", () => {
        expect(ppl.agent.type).to.equal("a1-standard-4")
        expect(ppl.agent.osImage).to.equal("macos-xcode11")
      })
    })

    describe("when the machine type is not defined", () => {
      let ppl = null;

      it("sets it to e1-standard-2 with ubuntu1804", () => {
        Agent.setupTestAgentTypes();
        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "blocks": []
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]
        expect(ppl.agent.type).to.equal("e1-standard-2")
        expect(ppl.agent.osImage).to.equal("ubuntu2004")
      })

      it("sets it to empty string if no machine type available", () => {
        Agent.setupTestNoAgentTypes();

        let pipeline1 = yaml.safeDump({
          "version": "1.0",
          "blocks": []
        })

        let wf = new Workflow({yamls: [pipeline1]})
        ppl = wf.pipelines[0]

        expect(ppl.agent.type).to.equal("")
        expect(ppl.agent.osImage).to.equal("")
      })
    })

    it("creates a list of containers", () => {
      let wf = new Workflow({yamls: [
        yaml.safeDump({
          "version": "1.0",
          "agent": {
            "machine": {
              "type": "a1-standard-4",
              "os_image": "macos-xcode11"
            },
            "containers": [
              {
                "name": "main",
                "image": "ubuntu1804"
              }
            ]
          },
          "blocks": []
        })
      ]})

      let agent = wf.pipelines[0].agent
      expect(agent.containers.length).to.equal(1)
      expect(agent.containers[0].name).to.equal("main")
      expect(agent.containers[0].image).to.equal("ubuntu1804")
    })

    describe("when the machine type is defined", () => {
      it("sets type to the provided one", () => {
        let wf = new Workflow({yamls: [
          yaml.safeDump({
            "version": "1.0",
            "agent": {
              "machine": {
                "type": "a1-standard-4",
                "os_image": "macos-xcode11"
              }
            },
            "blocks": []
          })
        ]})

        let ppl = wf.pipelines[0]

        expect(ppl.agent.type).to.equal("a1-standard-4")
        expect(ppl.agent.osImage).to.equal("macos-xcode11")
      })
    })
  })

  describe("#environmentType", () => {
    it("returns docker type if there is a container", () => {
      Agent.setupTestAgentTypes();

      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "e1-standard-2"
        },
        "containers": [
          {
            "name": "main",
            "image": "ubuntu:14.04"
          }
        ]
      })

      expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_DOCKER)
    })

    it("returns linux vm type if the machine name is in the available LINUX machines", () => {
      Agent.setupTestAgentTypes();

      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "e1-standard-2"
        }
      })

      expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_LINUX_VM)
    })

    it("return mac vm type if the machine name is in the available MAC machines", () => {
      Agent.setupTestAgentTypes();

      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "a1-standard-4"
        }
      })

      expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_MAC_VM)
    })

    it("return self-hosted vm type if the machine name is in the available SELF_HOSTED machines", () => {
      Agent.setupTestAgentTypes();

      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "s1-linux"
        }
      })

      expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_SELF_HOSTED)
    })

    it ("return unknown vm type if machine name is not available", () => {
      Agent.setupTestAgentTypes();

      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "e1-does-not-exist"
        }
      })

      expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_UNKNOWN)
    })

    it("return unavailable is no agent types exist", () => {
      Agent.setupTestNoAgentTypes();

      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "e1-standard-2"
        }
      })

      expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_UNAVAILABLE)
    })
  })

  describe("#changeEnvironmentType", () => {
    let agent = null;

    describe("#changing to linux VM type", () => {
      beforeEach(() => {
        Agent.setupTestAgentTypes();
        agent = new Agent(dummyParent, {
          "machine": {
            "type": "a1-standard-4"
          }
        })

        agent.changeEnvironmentType(Agent.ENVIRONMENT_TYPE_LINUX_VM)
      })

      it("sets the osImage to ubuntu", () => {
        expect(agent.osImage).to.equal("ubuntu2004")
      })

      it("sets the machine type to e1-standard-2", () => {
        expect(agent.type).to.equal("e1-standard-2")
      })

      it("sets the containers to empty", () => {
        expect(agent.containers.length).to.equal(0)
      })

      it("sets the environmentType to linux", () => {
        expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_LINUX_VM)
      })
    })

    describe("#changing to mac VM type", () => {
      beforeEach(() => {
        Agent.setupTestAgentTypes();
        agent = new Agent(dummyParent, {
          "machine": {
            "type": "e1-standard-2"
          }
        })

        agent.changeEnvironmentType(Agent.ENVIRONMENT_TYPE_MAC_VM)
      })

      it("sets the osImage", () => {
        expect(agent.osImage).to.equal("macos-xcode13")
      })

      it("sets the machine type to a1-standard-4", () => {
        expect(agent.type).to.equal("a1-standard-4")
      })

      it("sets the containers to empty", () => {
        expect(agent.containers.length).to.equal(0)
      })

      it("sets the environmentType to mac", () => {
        expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_MAC_VM)
      })
    })

    describe("#changing to docker containers", () => {
      beforeEach(() => {
        Agent.setupTestAgentTypes();
        agent = new Agent(dummyParent, {
          "machine": {
            "type": "a1-standard-4"
          }
        })

        agent.changeEnvironmentType(Agent.ENVIRONMENT_TYPE_DOCKER)
      })

      it("sets the osImage", () => {
        expect(agent.osImage).to.equal("ubuntu2004")
      })

      it("sets the machine type", () => {
        expect(agent.type).to.equal("e1-standard-2")
      })

      it("sets the main container", () => {
        let c1 = agent.containers[0]

        expect(c1.name).to.equal("main")
        expect(c1.image).to.equal("semaphoreci/ubuntu:20.04")
      })

      it("sets the environmentType to docker", () => {
        expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_DOCKER)
      })
    })

    describe("#changing to self-hosted VM type", () => {
      beforeEach(() => {
        Agent.setupTestAgentTypes();
        agent = new Agent(dummyParent, {
          "machine": {
            "type": "a1-standard-4"
          }
        })

        agent.changeEnvironmentType(Agent.ENVIRONMENT_TYPE_SELF_HOSTED)
      })

      it("sets the osImage", () => {
        expect(agent.osImage).to.equal("")
      })

      it("sets the machine type to the first agent type found", () => {
        expect(agent.type).to.equal("s1-linux")
      })

      it("sets the containers to empty", () => {
        expect(agent.containers.length).to.equal(0)
      })

      it("sets the environmentType to self-hosted", () => {
        expect(agent.environmentType()).to.equal(Agent.ENVIRONMENT_TYPE_SELF_HOSTED)
      })
    })
  })

  describe("#changeMachineType", () => {
    beforeEach(() => {
      Agent.setupTestAgentTypes();
    })

    it("sets the default os image for the machine type", () => {
      let pipeline1 = yaml.safeDump({
        "version": "1.0",
        "agent": {
          "machine": {
            "type": "e1-standard-2"
          }
        },
        "blocks": []
      })

      let wf = new Workflow({yamls: [pipeline1]})
      let ppl = wf.pipelines[0]

      ppl.agent.changeMachineType("a1-standard-4")
      expect(ppl.agent.osImage).to.equal("macos-xcode13")

      ppl.agent.changeMachineType("e1-standard-4")
      expect(ppl.agent.osImage).to.equal("ubuntu2004")
    })
  })

  describe("#toJson", () => {
    beforeEach(() => {
      Agent.setupTestAgentTypes();
    })

    it("renders machine type", () => {
      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "e1-standard-2"
        }
      })

      expect(agent.toJson()["machine"]["type"]).to.equal("e1-standard-2")
    })

    it("renders machine os_image", () => {
      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "e1-standard-2"
        }
      })

      expect(agent.toJson()["machine"]["os_image"]).to.equal("ubuntu2004")
    })

    it("renders containers", () => {
      let agent = new Agent(dummyParent, {
        "machine": {
          "type": "e1-standard-2"
        },
        "containers": [
          {
            "name": "main",
            "image": "ubuntu:14.04"
          }
        ]
      })

      expect(agent.toJson()["containers"]).to.deep.equal([
        {
          "image": "ubuntu:14.04",
          "name": "main"
        }
      ])
    })
  })

})
