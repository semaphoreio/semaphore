defmodule Notifications.Util.ValidatorTest do
  use Notifications.DataCase

  alias Notifications.Util.Validator
  alias Semaphore.Notifications.V1alpha.Notification
  alias Notification.{Metadata, Spec}
  alias Spec.Rule

  @user_id Ecto.UUID.generate()

  describe ".validate" do
    test "everything is valid" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  filter:
                    Rule.Filter.new(
                      projects: [
                        "/.*/"
                      ]
                    ),
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) == {:ok, :valid}
    end

    test "user_id is empty" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  filter:
                    Rule.Filter.new(
                      projects: [
                        "/.*/"
                      ]
                    ),
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, "") ==
               {:error, :invalid_argument, "Invalid user_id: expected a valid UUID"}
    end

    test "reports broken regexes" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    ),
                  filter:
                    Rule.Filter.new(
                      projects: [
                        "/*/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) ==
               {:error, :invalid_argument, "Pattern /*/ is not a valid regex statement"}
    end

    test "multiple reports broken regexes" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    ),
                  filter:
                    Rule.Filter.new(
                      projects: [
                        "/*/"
                      ],
                      branches: [
                        "/+dasdas/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) ==
               {:error, :invalid_argument,
                "Patterns [/*/, /+dasdas/] are not valid regex statements"}
    end

    test "reports wrong results value" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    ),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "pass"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) ==
               {:error, :invalid_argument,
                "Value pass is not a valid result entry. Valid values are: passed, failed, canceled, stopped."}
    end

    test "valid result values" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    ),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "passed",
                        "failed",
                        "canceled",
                        "stopped"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) == {:ok, :valid}
    end

    test "regex is valid result entry" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    ),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) == {:ok, :valid}
    end

    test "no notify target specified => not valid" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify: Rule.Notify.new(),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) ==
               {:error, :invalid_argument,
                "A notification rule must have at least one notification target configured."}
    end

    test "no notify field specified => not valid" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) ==
               {:error, :invalid_argument, "A notification rule must have a notify field."}
    end

    test "only valid slack target => valid" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    ),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    ),
                  name: "Example Rule"
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) == {:ok, :valid}
    end

    test "only valid webhook target => valid" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(
                      webhook: Rule.Notify.Webhook.new(endpoint: "https://whatever.com/hook")
                    ),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) == {:ok, :valid}
    end

    test "only valid email target => valid" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(email: Rule.Notify.Email.new(cc: ["user@whatever.com"])),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) == {:ok, :valid}
    end

    test "valid + invalid rule => fails" do
      n =
        Notification.new(
          metadata: Metadata.new(name: "A"),
          spec:
            Spec.new(
              rules: [
                Rule.new(
                  name: "Example Rule",
                  notify:
                    Rule.Notify.new(
                      slack:
                        Rule.Notify.Slack.new(
                          endpoint: "https://whatever.com",
                          channels: ["#testing-hq"]
                        )
                    ),
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    )
                ),
                Rule.new(
                  name: "Example Rule 2",
                  filter:
                    Rule.Filter.new(
                      results: [
                        "/^(?:passed|stopped)$/"
                      ]
                    )
                )
              ]
            )
        )

      assert Validator.validate(n, @user_id) ==
               {:error, :invalid_argument, "A notification rule must have a notify field."}
    end
  end

  describe ".validate endpoints" do
    test "accepts http and https endpoints and the allowed webhook actions" do
      for action <- ["", "POST", "put", "PATCH"] do
        n =
          notification(
            slack: Rule.Notify.Slack.new(endpoint: "https://hooks.slack.com/services/A"),
            webhook: Rule.Notify.Webhook.new(endpoint: "https://example.com/hook", action: action)
          )

        assert Validator.validate(n, @user_id) == {:ok, :valid}
      end
    end

    test "rejects a webhook endpoint with control characters" do
      n =
        notification(
          webhook:
            Rule.Notify.Webhook.new(endpoint: "https://example.com/hook?a=1\r\nX-Header: value")
        )

      assert {:error, :invalid_argument, message} = Validator.validate(n, @user_id)
      assert message =~ "characters that are not allowed"
    end

    test "rejects a Slack endpoint that is not http or https" do
      n =
        notification(
          slack: Rule.Notify.Slack.new(endpoint: "http+unix://%2Fvar%2Frun%2Fdocker.sock/info")
        )

      assert {:error, :invalid_argument, message} = Validator.validate(n, @user_id)
      assert message =~ "must start with http:// or https://"
    end

    test "rejects an unsupported webhook action" do
      n =
        notification(
          webhook: Rule.Notify.Webhook.new(endpoint: "https://example.com/hook", action: "GET")
        )

      assert {:error, :invalid_argument, message} = Validator.validate(n, @user_id)
      assert message =~ "is not supported"
    end

    test "checks internal API notifications too" do
      alias InternalApi.Notifications.Notification, as: Internal

      n =
        Internal.new(
          name: "A",
          rules: [
            Internal.Rule.new(
              name: "Example Rule",
              filter: Internal.Rule.Filter.new(projects: ["/.*/"]),
              notify:
                Internal.Rule.Notify.new(
                  webhook: Internal.Rule.Notify.Webhook.new(endpoint: "https://example.com/a b")
                )
            )
          ]
        )

      assert {:error, :invalid_argument, _} = Validator.validate(n, @user_id)
    end
  end

  defp notification(notify) do
    Notification.new(
      metadata: Metadata.new(name: "A"),
      spec:
        Spec.new(
          rules: [
            Rule.new(
              name: "Example Rule",
              filter: Rule.Filter.new(projects: ["/.*/"]),
              notify: Rule.Notify.new(notify)
            )
          ]
        )
    )
  end
end
