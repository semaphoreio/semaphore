defmodule Front.Support.HelpscoutRequest do
  @doc """
  Topic and Field IDs differ for Mailboxes.
  We use:
  - Semaphore Support Mailbox on HelpScout for requests comming from production
  - Test Support Mailbox on HelpScout for requests comming from other environments
  """
  def mailbox_id do
    case Application.get_env(:front, :environment) do
      :prod -> "94818"
      _ -> "98169"
    end
  end

  def topic_field_id do
    case Application.get_env(:front, :environment) do
      :prod -> 2_578
      _ -> 2_579
    end
  end

  def provided_link_field_id do
    case Application.get_env(:front, :environment) do
      :prod -> 2_396
      _ -> 2_411
    end
  end

  @doc """
  Returns the ID of a topic within HelpScout Mailbox.

  IDs can be fetched as follows:
    url = "https://api.helpscout.net/v2/mailboxes/:mailbox_id/fields"
    headers = [ "Authorization": "Bearer :access_token"]
    HTTPoison.get(url, headers, [])
  """
  def get_topic_id(topic) do
    mailbox_topic_ids =
      case Application.get_env(:front, :environment) do
        :prod ->
          %{
            "API" => 16_667,
            "Workflows" => 12_590,
            "Dependency Caching" => 12_591,
            "Deployment" => 12_592,
            "Docker" => 12_593,
            "Feature Request" => 12_594,
            "Feedback" => 12_595,
            "Git Service" => 12_596,
            "Organizations & Users" => 12_597,
            "Payment" => 12_598,
            "Pre-installed Software" => 12_599,
            "Pricing" => 12_600,
            "UX" => 12_602,
            "Other" => 12_603
          }

        _ ->
          %{
            "API" => 16_666,
            "Workflows" => 12_604,
            "Dependency Caching" => 12_605,
            "Deployment" => 12_606,
            "Docker" => 12_617,
            "Feature Request" => 12_607,
            "Feedback" => 12_608,
            "Git Service" => 12_609,
            "Organizations & Users" => 12_610,
            "Payment" => 12_611,
            "Pre-installed Software" => 12_612,
            "Pricing" => 12_613,
            "UX" => 12_615,
            "Other" => 12_616
          }
      end

    Map.get(mailbox_topic_ids, topic)
  end

  def compose(support_request) do
    # setting autoReply to true based on the HelpScout docs:
    ## The autoReply request parameter enables auto replies to be sent
    ## when a conversation is created via the API.
    ## When autoReply is set to true, an auto reply will be sent
    ## as long as there is at least one customer thread in the conversation.
    %{
      subject: support_request.subject,
      autoReply: true,
      customer: %{
        email: support_request.email
      },
      mailboxId: mailbox_id(),
      type: "email",
      status: "active",
      threads: [
        %{
          type: "customer",
          customer: %{email: support_request.email},
          text: support_request.body,
          attachments: compose_attachments(support_request)
        }
      ],
      tags: support_request.tags,
      fields: [
        %{
          id: topic_field_id(),
          value: get_topic_id(support_request.topic)
        },
        %{
          id: provided_link_field_id(),
          value: support_request.provided_link
        }
      ]
    }
    |> Poison.encode!()
  end

  defp compose_attachments(input) do
    if Map.get(input, :file_name) do
      [
        %{
          fileName: input.file_name,
          mimeType: input.file_type,
          data: input.file_data
        }
      ]
    else
      []
    end
  end
end
