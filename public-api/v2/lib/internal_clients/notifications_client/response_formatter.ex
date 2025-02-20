defmodule InternalClients.Notifications.ResponseFormatter do
  @moduledoc """
  Module parses the response from Notifications service
  """
  alias InternalApi.Notifications, as: API

  def process_response({:ok, r = %API.ListResponse{}}) do
    {:ok, list_from_pb(r)}
  end

  def process_response({:ok, r = %API.DescribeResponse{}}) do
    {:ok, notification_from_pb(r.notification)}
  end

  def process_response({:ok, r = %API.DestroyResponse{}}) do
    {:ok, %{id: r.id}}
  end

  def process_response({:ok, r = %API.CreateResponse{}}) do
    {:ok, notification_from_pb(r.notification)}
  end

  def process_response({:ok, r = %API.UpdateResponse{}}) do
    {:ok, notification_from_pb(r.notification)}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [5, :not_found] do
    {:error, {:not_found, message}}
  end

  def process_response({:error, %GRPC.RPCError{status: status, message: message}})
      when status in [3, :invalid_argument] do
    {:error, {:user, message}}
  end

  def process_response({:error, error}), do: {:error, {:internal, error}}

  defp list_from_pb(response = %API.ListResponse{}) do
    %{
      next_page_token: response.next_page_token,
      entries: Enum.map(response.notifications, &notification_from_pb/1)
    }
  end

  defp notification_from_pb(n = %API.Notification{}) do
    %{
      apiVersion: "v2",
      kind: "Notification",
      metadata: metadata_from_pb(n),
      spec: spec_from_pb(n)
    }
  end

  defp metadata_from_pb(n = %API.Notification{}) do
    %{
      id: n.id,
      name: n.name,
      created_at: PublicAPI.Util.Timestamps.to_timestamp(n.create_time),
      updated_at: PublicAPI.Util.Timestamps.to_timestamp(n.update_time),
      org_id: n.org_id,
      status: status_from_pb(n.status)
    }
  end

  defp status_from_pb(nil), do: %{failures: []}

  defp status_from_pb(status = %API.Notification.Status{}) do
    %{
      failures: Enum.map(status.failures, &failure_from_pb/1)
    }
  end

  defp failure_from_pb(failure = %API.Notification.Status.Failure{}) do
    %{
      timestamp: PublicAPI.Util.Timestamps.to_timestamp(failure.time),
      description: failure.message
    }
  end

  defp spec_from_pb(n = %API.Notification{}) do
    %{
      name: n.name,
      rules: Enum.map(n.rules, &rule_from_pb/1)
    }
  end

  defp rule_from_pb(rule = %API.Notification.Rule{}) do
    %{
      name: rule.name,
      filter: %{
        projects: rule.filter.projects,
        branches: rule.filter.branches,
        pipelines: rule.filter.pipelines,
        blocks: rule.filter.blocks,
        states: rule.filter.states |> Enum.map(&Atom.to_string/1),
        results: rule.filter.results |> Enum.map(&Atom.to_string/1)
      },
      notify: %{
        slack: slack_from_pb(rule.notify.slack),
        email: email_from_pb(rule.notify.email),
        webhook: webhook_from_pb(rule.notify.webhook)
      }
    }
  end

  defp slack_from_pb(nil), do: nil

  defp slack_from_pb(slack = %API.Notification.Rule.Notify.Slack{}) do
    %{
      endpoint: slack.endpoint,
      channels: slack.channels,
      message: slack.message,
      status: rule_status_from_pb(slack.status)
    }
  end

  defp email_from_pb(nil), do: nil

  defp email_from_pb(email = %API.Notification.Rule.Notify.Email{}) do
    %{
      cc: email.cc,
      subject: email.subject,
      bcc: email.bcc,
      content: email.content,
      status: rule_status_from_pb(email.status)
    }
  end

  defp webhook_from_pb(nil), do: nil

  defp webhook_from_pb(webhook = %API.Notification.Rule.Notify.Webhook{}) do
    %{
      url: webhook.endpoint,
      method: webhook.action,
      retries: webhook.retries,
      timeout: webhook.timeout,
      secret: webhook.secret,
      status: rule_status_from_pb(webhook.status)
    }
  end

  defp rule_status_from_pb(status) do
    Atom.to_string(status)
  end
end
