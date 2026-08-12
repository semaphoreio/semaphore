import { expect } from "chai";

import { Pipeline } from "./pipeline";
import { Block } from "./block";
import { Agent } from "./agent";

describe("partial_rerun in the workflow editor", () => {
  Agent.setupTestAgentTypes();

  const workflow = { afterUpdate: () => {}, initialYAMLPath: ".semaphore/semaphore.yml" };
  const parent = { afterUpdate: () => {} };

  const pipelineWith = (extra) =>
    Pipeline.fromYaml(
      workflow,
      `version: v1.0
name: Test
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
${extra}
blocks:
  - name: Unit tests
    task:
      jobs:
        - name: unit
          commands:
            - make test
`,
      ".semaphore/semaphore.yml"
    );

  describe("pipeline level", () => {
    it("is empty when the property is absent", () => {
      expect(pipelineWith("").partialRerun).to.equal("");
    });

    it("is read from the yaml and survives a round trip", () => {
      const pipeline = pipelineWith("partial_rerun: block");

      expect(pipeline.partialRerun).to.equal("block");
      expect(pipeline.toJson().partial_rerun).to.equal("block");
    });

    it("is written when set", () => {
      const pipeline = pipelineWith("");

      pipeline.setPartialRerun("block");

      expect(pipeline.toJson().partial_rerun).to.equal("block");
    });

    it("is dropped from the yaml when set back to the default", () => {
      const pipeline = pipelineWith("partial_rerun: block");

      pipeline.setPartialRerun("");

      expect(pipeline.toJson()).to.not.have.property("partial_rerun");
    });

    it("does not leak the pipeline value into its blocks", () => {
      const pipeline = pipelineWith("partial_rerun: block");

      expect(pipeline.blocks[0].toJson()).to.not.have.property("partial_rerun");
    });
  });

  describe("schema validation", () => {
    it("accepts the property at both levels", () => {
      const pipeline = Pipeline.fromYaml(
        workflow,
        `version: v1.0
name: Test
agent:
  machine:
    type: e1-standard-2
    os_image: ubuntu2004
partial_rerun: jobs
blocks:
  - name: Unit tests
    partial_rerun: block
    task:
      jobs:
        - name: unit
          commands:
            - make test
`,
        ".semaphore/semaphore.yml"
      );

      pipeline.validate();

      expect(pipeline.schemaErrors).to.deep.equal([]);
      expect(pipeline.hasSchemaErrors()).to.equal(false);
    });
  });

  describe("block level", () => {
    const blockWith = (extra) =>
      new Block(parent, Object.assign({ name: "A", task: { jobs: [] } }, extra));

    it("is empty when the property is absent", () => {
      expect(blockWith({}).partialRerun).to.equal("");
    });

    it("is read from the structure and survives a round trip", () => {
      const block = blockWith({ partial_rerun: "jobs" });

      expect(block.partialRerun).to.equal("jobs");
      expect(block.toJson().partial_rerun).to.equal("jobs");
    });

    it("is dropped when set back to following the pipeline", () => {
      const block = blockWith({ partial_rerun: "block" });

      block.setPartialRerun("");

      expect(block.toJson()).to.not.have.property("partial_rerun");
    });

    it("is written when set", () => {
      const block = blockWith({});

      block.setPartialRerun("block");

      expect(block.toJson().partial_rerun).to.equal("block");
    });
  });
});
