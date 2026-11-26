defmodule Notifications.Util.TransformsTest do
  use ExUnit.Case, async: true

  alias Notifications.Util.Transforms
  alias Semaphore.Notifications.V1alpha.Notification.Spec

  defp stored_spec(notify) do
    Spec.new(
      rules: [
        Spec.Rule.new(
          name: "r",
          filter: Spec.Rule.Filter.new(projects: ["p"]),
          notify: Spec.Rule.Notify.new(notify)
        )
      ]
    )
    |> Transforms.encode_spec()
  end

  test "a rule with only a webhook decodes for the public API" do
    spec =
      stored_spec(webhook: Spec.Rule.Notify.Webhook.new(endpoint: "https://example.com/hook"))

    rule = hd(Transforms.decode_spec(spec, Spec).rules)

    assert rule.notify.webhook.endpoint == "https://example.com/hook"
  end

  test "a rule with only Slack decodes for the public API" do
    spec = stored_spec(slack: Spec.Rule.Notify.Slack.new(endpoint: "https://hooks.slack.com/x"))

    rule = hd(Transforms.decode_spec(spec, Spec).rules)

    assert rule.notify.slack.endpoint == "https://hooks.slack.com/x"
  end

  test "a rule with only a webhook decodes for the internal API" do
    spec =
      stored_spec(webhook: Spec.Rule.Notify.Webhook.new(endpoint: "https://example.com/hook"))

    rule = hd(Transforms.decode_spec(spec["rules"], InternalApi.Notifications.Notification.Rule))

    assert rule.notify.webhook.endpoint == "https://example.com/hook"
  end
end
