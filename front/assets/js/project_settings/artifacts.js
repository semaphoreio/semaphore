import $ from "jquery"
import _ from "lodash"

import { RetentionPolicyForm } from "./artifacts/retention_policy_form"

export class ProjectArtifactsSettings {
  static init() {
    let form = $("form#project-artifacts-retention-policy-form")
    let data = window.InjectedDataByBackend.ArtifactRetentionPolicies

    new RetentionPolicyForm(form, data)
  }
}
