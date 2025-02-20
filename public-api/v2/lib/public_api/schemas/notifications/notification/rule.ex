defmodule PublicAPI.Schemas.Notifications.Notification.Rule do
  @moduledoc """
  Schema for a notification rule
  """
  use PublicAPI.SpecHelpers.Schema

  OpenApiSpex.schema(%{
    title: "Notifications.Notification.Rule",
    type: :object,
    required: [],
    properties: %{
      name: %Schema{
        type: :string,
        description: "Name of the notification rule"
      },
      filter: %Schema{
        type: :object,
        description: "Filter for the notification rule",
        properties: %{
          projects: %Schema{
            type: :array,
            description: ~s(List of project names to trigger this rule. Default no projects.
             Examples:
              - "cli" - strictly match the CLI project
              - "/^s2-*/" - regex mathes projects that start with 's2-' prefix),
            items: %Schema{
              type: :string
            }
          },
          branches: %Schema{
            type: :array,
            description: ~s(List of branch names to trigger this rule. Default: all branches.
             Examples:
               - "master" - strictly match the master branch
               - "/^release-*/" - regex matches branches that start with 'release-' prefix),
            items: %Schema{
              type: :string
            }
          },
          pipelines: %Schema{
            type: :array,
            default: "semaphore.yml",
            description:
              ~s(List of pipeline names to trigger this rule. The rule matches pipeline file name disregarding the path.
            Examples:
              - "semaphore.yml" - will match `semaphore.yml` pipeline
              - "/^stg-*/" - regex matches pipelines that start with 'stg-' prefix),
            items: %Schema{
              type: :string
            }
          },
          results: %Schema{
            type: :array,
            description: "List of results to trigger this rule. Default: every result.",
            items: %Schema{
              description:
                ~s(Either a string or a regex, possible values: `PASSED`, `STOPPED`, `CANCELED`, `FAILED`.),
              type: :string,
              enum: ~w(PASSED STOPPED CANCELED FAILED)
            }
          }
        }
      },
      notify: %Schema{
        type: :object,
        description: "Notification settings",
        required: [],
        properties: %{
          slack: %Schema{
            type: :object,
            description: "Slack notification settings",
            nullable: true,
            required: [:endpoint],
            properties: %{
              endpoint: %Schema{
                type: :string,
                description: "Slack endpoint"
              },
              channels: %Schema{
                type: :array,
                description: "Slack channels",
                items: %Schema{
                  type: :string
                }
              },
              message: %Schema{
                type: :string,
                description: "Slack message"
              },
              status: PublicAPI.Schemas.Notifications.Notification.Rule.Status.schema()
            }
          },
          email: %Schema{
            type: :object,
            description: "Email notification settings",
            nullable: true,
            required: [:cc],
            properties: %{
              cc: %Schema{
                type: :array,
                description: "Email CC",
                minItems: 1,
                items: %Schema{
                  type: :string
                }
              },
              subject: %Schema{
                type: :string,
                description: "Email subject"
              },
              bcc: %Schema{
                type: :array,
                description: "Email BCC",
                items: %Schema{
                  type: :string
                }
              },
              content: %Schema{
                type: :string,
                description: "Email content"
              },
              status: PublicAPI.Schemas.Notifications.Notification.Rule.Status.schema()
            }
          },
          webhook: %Schema{
            type: :object,
            description: "Webhook notification settings",
            nullable: true,
            required: [:url],
            properties: %{
              url: %Schema{
                type: :string,
                description: "Webhook HTTP endpoint to hit."
              },
              timeout: %Schema{
                type: :integer,
                description: "Webhook delivery timeout in ms",
                default: 500
              },
              method: %Schema{
                type: :string,
                description: "Webhook http verb",
                default: "POST"
              },
              retries: %Schema{
                type: :integer,
                description: "Number of times to retry delivery.",
                maximum: 3,
                minimum: 1,
                default: 3
              },
              secret: %Schema{
                type: :string,
                description: "Name of a Semaphore secret, which will be used to sign the payload."
              },
              status: PublicAPI.Schemas.Notifications.Notification.Rule.Status.schema()
            }
          }
        }
      }
    }
  })
end
