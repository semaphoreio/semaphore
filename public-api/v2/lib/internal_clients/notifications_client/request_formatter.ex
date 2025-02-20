defmodule InternalClients.Notifications.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into
  protobuf messages suitable for gRPC communication with Notifications service.
  """

  alias InternalApi.Notifications, as: API
  import InternalClients.Common

  @on_load :load_atoms

  defp load_atoms() do
    [
      API.Notification.Spec.Rule.Filter.State,
      API.Notification.Spec.Rule.Filter.Results
    ]
    |> Enum.each(&Code.ensure_loaded/1)
  end

  # List keyset

  def form_request({API.ListRequest, params}) do
    {:ok,
     %API.ListRequest{
       metadata: metadata(params),
       page_size: from_params(params, :page_size),
       page_token: from_params(params, :page_token)
     }}
  rescue
    error in ArgumentError ->
      {:error, {:user, error.message}}
  end

  def form_request({API.DescribeRequest, params}) do
    {:ok,
     %API.DescribeRequest{
       metadata: metadata(params),
       id: from_params(params, :id),
       name: from_params(params, :name)
     }}
  end

  def form_request({API.DestroyRequest, params}) do
    {:ok,
     %API.DestroyRequest{
       metadata: metadata(params),
       id: from_params(params, :id),
       name: from_params(params, :name)
     }}
  end

  def form_request({API.CreateRequest, params}) do
    {:ok,
     %API.CreateRequest{
       metadata: metadata(params),
       notification: form_request({API.Notification, params})
     }}
  end

  def form_request({API.UpdateRequest, params}) do
    {:ok,
     %API.UpdateRequest{
       metadata: metadata(params),
       id: from_params(params, :id),
       name: from_params(params, :name),
       notification: form_request({API.Notification, params})
     }}
  end

  def form_request({API.Notification, params}) do
    %API.Notification{
      name: from_params(params.spec, :name),
      rules: Enum.map(from_params!(params.spec, :rules), &rule/1)
    }
  end

  defp metadata(params) do
    %API.RequestMeta{
      user_id: from_params!(params, :user_id),
      org_id: from_params!(params, :organization_id)
    }
  end

  defp rule(rule) do
    %API.Notification.Rule{
      name: from_params!(rule, :name),
      filter: filter(from_params!(rule, :filter)),
      notify: notify(from_params!(rule, :notify))
    }
  end

  defp filter(params) do
    params |> LogTee.debug("Filter params")

    %API.Notification.Rule.Filter{
      projects: from_params(params, :projects),
      branches: from_params(params, :branches),
      pipelines: from_params(params, :pipelines),
      blocks: from_params(params, :blocks),
      states: Enum.map(from_params(params, :states, []), &String.to_existing_atom/1),
      results: Enum.map(from_params(params, :results, []), &String.to_existing_atom/1)
    }
  end

  defp notify(params) do
    %API.Notification.Rule.Notify{
      email: email(from_params(params, :email)),
      slack: slack(from_params(params, :slack)),
      webhook: webhook(from_params(params, :webhook))
    }
  end

  defp email(nil), do: nil

  defp email(params) do
    %API.Notification.Rule.Notify.Email{
      bcc: from_params(params, :bcc),
      cc: from_params(params, :cc),
      content: from_params(params, :content),
      subject: from_params(params, :subject),
      status: String.to_atom(from_params(params, :status))
    }
  end

  defp slack(nil), do: nil

  defp slack(params) do
    %API.Notification.Rule.Notify.Slack{
      channels: from_params(params, :channels),
      endpoint: from_params(params, :endpoint),
      message: from_params(params, :message),
      status: String.to_atom(from_params(params, :status))
    }
  end

  defp webhook(nil), do: nil

  defp webhook(params) do
    %API.Notification.Rule.Notify.Webhook{
      endpoint: from_params(params, :endpoint),
      action: from_params(params, :action),
      retries: from_params(params, :retries),
      timeout: from_params(params, :timeout),
      secret: from_params(params, :secret),
      status: String.to_atom(from_params(params, :status))
    }
  end
end
