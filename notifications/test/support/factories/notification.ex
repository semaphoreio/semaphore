defmodule Support.Factories.Notification do
  def build(name, params \\ %{}) do
    Map.merge(
      %{
        org_id: Ecto.UUID.generate(),
        name: name
      },
      params
    )
  end

  def api_model(name) do
    alias Semaphore.Notifications.V1alpha.Notification
    alias Notification.{Metadata, Spec}
    alias Spec.Rule

    Notification.new(
      metadata: Metadata.new(name: name),
      spec:
        Spec.new(
          rules: [
            Rule.new(
              name: "Example Rule",
              filter:
                Rule.Filter.new(
                  projects: [
                    "cli",
                    "/^s2-*/"
                  ],
                  branches: [
                    "master",
                    "/^release-.*$/"
                  ],
                  pipelines: [
                    ".semaphore/semaphore.yml",
                    "/^\.semaphore\/stg-*.yml/"
                  ]
                ),
              notify:
                Rule.Notify.new(
                  slack:
                    Rule.Notify.Slack.new(
                      endpoint: "https://slack.com/api/dsasdf3243/34123412h1j2h34kj2",
                      channels: [
                        "#general",
                        "#product-hq"
                      ],
                      message: "Slack notification!"
                    ),
                  email:
                    Rule.Notify.Email.new(
                      subject: "Hi there",
                      cc: [
                        "devops@example.com"
                      ],
                      bcc: [
                        "devs@example.com"
                      ],
                      content: "Email notification 101"
                    ),
                  webhook:
                    Rule.Notify.Webhook.new(
                      endpoint: "https://githu.com/api/comments",
                      timeout: 500,
                      action: "POST",
                      secret: "B7L2XRJ12"
                    )
                )
            )
          ]
        )
    )
  end

  def internal_api_model(name) do
    alias InternalApi.Notifications.Notification
    alias Notification.Rule

    Notification.new(
      name: name,
      rules: [
        Rule.new(
          name: "Example Rule",
          filter:
            Rule.Filter.new(
              projects: [
                "cli",
                "/^s2-*/"
              ],
              branches: [
                "master",
                "/^release-.*$/"
              ],
              pipelines: [
                ".semaphore/semaphore.yml",
                "/^\.semaphore\/stg-*.yml/"
              ]
            ),
          notify:
            Rule.Notify.new(
              slack:
                Rule.Notify.Slack.new(
                  endpoint: "https://slack.com/api/dsasdf3243/34123412h1j2h34kj2",
                  channels: [
                    "#general",
                    "#product-hq"
                  ],
                  message: "Slack notification!"
                ),
              email:
                Rule.Notify.Email.new(
                  subject: "Hi there",
                  cc: [
                    "devops@example.com"
                  ],
                  bcc: [
                    "devs@example.com"
                  ],
                  content: "Email notification 101"
                ),
              webhook:
                Rule.Notify.Webhook.new(
                  endpoint: "https://githu.com/api/comments",
                  timeout: 500,
                  action: "POST",
                  secret: "B7L2XRJ12"
                )
            )
        )
      ]
    )
  end
end
