defmodule Notifications.Util.RuleFactory do
  alias Notifications.Repo
  alias Notifications.Models

  #
  # notification: row from DB
  # rules: from the API resource
  #
  def persist_rules(notification, rules) do
    Enum.each(rules, fn rule ->
      create_rule(notification.org_id, notification.id, rule)
    end)

    :ok
  end

  def create_rule(org_id, notification_id, rule) do
    rule = %{rule | notify: Notifications.Util.Transforms.encode_notify(rule.notify)}

    r =
      Models.Rule.new(
        org_id,
        notification_id,
        rule.name,
        rule.notify.slack,
        rule.notify.email,
        rule.notify.webhook
      )

    {:ok, r} = Repo.insert(r)

    patterns =
      [] ++
        Models.Pattern.new(org_id, r.id, rule.filter.projects, "project") ++
        Models.Pattern.new(org_id, r.id, rule.filter.branches, "branch") ++
        Models.Pattern.new(org_id, r.id, rule.filter.pipelines, "pipeline") ++
        Models.Pattern.new(org_id, r.id, rule.filter.blocks, "block") ++
        Models.Pattern.new(org_id, r.id, rule.filter.results, "result") ++
        Models.Pattern.new(org_id, r.id, rule.filter.tags, "tag")

    # create block rules if doesn't exists
    patterns =
      if rule.filter.blocks == [] do
        patterns ++ Models.Pattern.new(org_id, r.id, ["/.*/"], "block")
      else
        patterns
      end

    # create branch rules if doesn't exists
    patterns =
      if rule.filter.branches == [] do
        patterns ++ Models.Pattern.new(org_id, r.id, ["/.*/"], "branch")
      else
        patterns
      end

    # create pipelines rules if doesn't exists
    patterns =
      if rule.filter.pipelines == [] do
        patterns ++ Models.Pattern.new(org_id, r.id, ["/.*/"], "pipeline")
      else
        patterns
      end

    # create result rules if don't exist
    patterns =
      if rule.filter.results == [] do
        patterns ++ Models.Pattern.new(org_id, r.id, ["/.*/"], "result")
      else
        patterns
      end

    # create tag rules if don't exist
    patterns =
      if Map.get(rule.filter, :tags, []) == [] do
        patterns ++ Models.Pattern.new(org_id, r.id, ["/.*/"], "tag")
      else
        patterns
      end

    Enum.map(patterns, fn p ->
      {:ok, _} = Repo.insert(p)
    end)
  end
end
