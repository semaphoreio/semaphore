import $ from "jquery"

export var EditNotification = {
  init: function() {
    $("body").on("click", ".remove-rule", function(event) {
      $(event.target).closest(".rule-container").remove();
      return false;
    });

    $("body").on("click", ".add-rule", function(event) {
      let add_rule = $(".add-rule");
      let rule_hash  = Math.random().toString(36).substr(2, 3); // njsscan-ignore: node_insecure_random_generator
      let empty_rule_form =
        `<div class="mv3 pa3 bg-white shadow-1 br3 rule-container">
            <div class="w-100 w-75-m mb3">
              <label for="rule" class="db b mb1">Name of the Rule</label>
              <input id="rule" name="rule_${rule_hash}[name]" type="text"
                     class="form-control w-100"
                     placeholder="e.g. On master branches" >
            </div>

            <p class="mb3">
              After Successful or Failed pipeline…
            </p>

            <div class="pl4 mb3">
              <label for="projects" class="db b mb1">in Projects</label>
              <input id="projects" name="rule_${rule_hash}[projects]" type="text"
                     class="form-control w-100"
                     placeholder="e.g. my-project, /hotfix-*/, /.*/" >
              <p class="f6 mt1 mb0 nb1">Comma separated, regular expressions allowed</p>
              <p class="f6 mt2 pa2 bg-washed-yellow ba b--yellow br2">
                  <strong>Note:</strong> Regardless of the regex patterns specified, notifications will only be sent for projects to which the creator of this notification has access.
              </p>
            </div>

            <div class="pl4 mb3">
              <label for="branches" class="db b mb1">
                Branches
                <span class="f6 normal gray"> · optional</span>
              </label>
              <input id="branches" name="rule_${rule_hash}[branches]" type="text"
                     class="form-control w-100"
                     placeholder="e.g. master, /prod-*/, /.*/" >
              <p class="f6 mt1 mb0 nb1">Comma separated, regular expressions allowed</p>
            </div>

            <div class="pl4 mb3">
              <label for="pipelines" class="db b mb1">
                Pipelines
                <span class="f6 normal gray"> · optional</span>
              </label>
              <input id="pipelines" name="rule_${rule_hash}[pipelines]" type="text"
                     class="form-control w-100"
                     placeholder="e.g. staging-deploy.yml, production-deploy.yml" >
              <p class="f6 mt1 mb0 nb1">Comma separated, regular expressions allowed</p>
            </div>

            <div class="pl4 mb3">
              <label for="results" class="db b mb1">
                Results
                <span class="f6 normal gray"> · optional</span>
              </label>
              <input id="results" name="rule_${rule_hash}[results]" type="text"
                     class="form-control w-100"
                     placeholder="e.g. stopped, failed" >
              <p class="f6 mt1 mb0 nb1">Comma separated</p>
            </div>

            <p class="mb3">
              Send notification to Slack…
            </p>

            <div class="pl4 mb3">
              <label for="slack-endpoint" class="db b mb1">
                Slack Endpoint
              </label>
              <input id="slack-endpoint" name="rule_${rule_hash}[slack_endpoint]" type="text"
                     class="form-control w-100"
                     placeholder="https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXX" >
              <p class="f6 mt1 mb0 nb1">How to find my <a href="https://get.slack.help/hc/en-us/articles/115005265063-Incoming-WebHooks-for-Slack" target="_blank" rel="noopener">Slack webhook</a>?</p>
            </div>

            <div class="pl4 mb3">
              <label for="slack_channels" class="db b mb1">
                Send to Slack channel(s)
              </label>
              <input id="slack_channels" name="rule_${rule_hash}[slack_channels]" type="text"
                     class="form-control w-100"
                     placeholder="e.g. #general, #development" >
              <p class="f6 mt1 mb0 nb1">Comma separated</p>
            </div>

            <p class="mb3">And/Or to a webhook…</p>

            <div class="pl4 mb3">
              <label for="webhook_endpoint" class="db b mb1">
                Endpoint
              </label>
              <input id="webhook_endpoint" name="rule_${rule_hash}[webhook_endpoint]" type="text"
                     class="form-control w-100"
                     placeholder="https://example.com/webhook" >
            </div>

            <div class="pl4 mb3">
              <label for="webhook_secret" class="db b mb1">
                Secret name
              </label>
              <input id="webhook_secret" name="rule_${rule_hash}[webhook_secret]" type="text"
                     class="form-control w-100"
                     placeholder="webhook-secret">
              <p class="f6 mt1 mb0 nb1">Read more about <a href="https://docs.semaphoreci.com/essentials/webhook-notifications/#securing-webhook-notifications" target="_blank" rel="noopener">securing webhook notifications</a></p>
            </div>

            <div class="f6 tc bt b--lighter-gray pv2 mt4 nh3 nb3 bg-washed-gray br3 br--bottom">
              <a href="#" class="link gray hover-dark-gray remove-rule">Delete Rule…</a>
            </div>

       </div>`

      add_rule.before(empty_rule_form)
      return false;
    });
  }
}
