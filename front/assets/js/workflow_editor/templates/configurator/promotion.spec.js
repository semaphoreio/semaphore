import yaml from "js-yaml"
import _ from "lodash"
import { expect } from "chai"

import { Features } from "../../../features";
import { Promotion } from "../../models/promotion";
import { Workflow } from "../../models/workflow";
import { Agent } from "../../models/agent";
import { PromotionConfigTemplate } from "./promotion";
import { escapeHtml } from "../../../escape_html";

describe("PromotionConfigTemplate", () => {
  beforeEach(() => {
    global.escapeHtml = escapeHtml;
  })

  describe("#deploymentTargets", () => {
    describe("when target is configured", () => {
      it("renders it as selected", () => {
        Features.setFeature("deploymentTargets", true)
        Promotion.setValidDeploymentTargets(["Staging", "Production"])

        const promotion = { "name": "Prod", "deployment_target": "Production" }
        const workflow = testWorkflow([promotion])
        workflow.validate()

        const wfPromotion = workflow.pipelines[0].promotions[0]
        const renderedHtml = PromotionConfigTemplate.deploymentTargets(wfPromotion)

        expect(renderedHtml).not.to.contain("form-control-error")
        expect(renderedHtml).not.to.contain("<p class=\"f6 mb0 red\">")

        expect(renderedHtml).to.contain("<option value=\"\">No target</option>")
        expect(renderedHtml).to.contain("<option value=\"Production\" selected>Target: Production</option>")
        expect(renderedHtml).to.contain("<option value=\"Staging\">Target: Staging</option>")
      })
    })

    describe("when target is not configured", () => {
      it("renders no target as selected ", () => {
        Features.setFeature("deploymentTargets", true)
        Promotion.setValidDeploymentTargets(["Staging", "Production"])

        const promotion = { "name": "Prod" }
        const workflow = testWorkflow([promotion])
        workflow.validate()

        const wfPromotion = workflow.pipelines[0].promotions[0]
        const renderedHtml = PromotionConfigTemplate.deploymentTargets(wfPromotion)

        expect(renderedHtml).not.to.contain("form-control-error")
        expect(renderedHtml).not.to.contain("<p class=\"f6 mb0 red\">")

        expect(renderedHtml).to.contain("<option value=\"\" selected>No target</option>")
        expect(renderedHtml).to.contain("<option value=\"Production\">Target: Production</option>")
        expect(renderedHtml).to.contain("<option value=\"Staging\">Target: Staging</option>")
      })
    })

    describe("when target is configured badly", () => {
      it("invalid option is selected ", () => {
        Features.setFeature("deploymentTargets", true)
        Promotion.setValidDeploymentTargets(["Staging", "Production"])

        const promotion = { "name": "Prod", "deployment_target": "Canary" }
        const workflow = testWorkflow([promotion])
        workflow.validate()

        const wfPromotion = workflow.pipelines[0].promotions[0]
        const renderedHtml = PromotionConfigTemplate.deploymentTargets(wfPromotion)

        expect(renderedHtml).to.contain("form-control-error")
        expect(renderedHtml).to.contain("<p class=\"f6 mb0 red\">Deployment target \"Canary\" is not available for this project</p>")

        expect(renderedHtml).to.contain("<option value=\"Canary\" selected disabled>Target: Canary</option>")
        expect(renderedHtml).to.contain("<option value=\"\">No target</option>")
        expect(renderedHtml).to.contain("<option value=\"Production\">Target: Production</option>")
        expect(renderedHtml).to.contain("<option value=\"Staging\">Target: Staging</option>")
      })
    })
  })
})

function testWorkflow(promotions) {
  Agent.setupTestAgentTypes();

  return new Workflow({
    yamls: [
      yaml.safeDump({
        "version": "1.0",
        "blocks": [{ "name": "A" }],
        "promotions": promotions
      })
    ]
  })
}
