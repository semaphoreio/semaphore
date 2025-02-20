defmodule Notifications.Workers.Webhook.Secret do
  require Logger
  alias Util.{Proto, ToTuple}

  alias InternalApi.Secrethub.{DescribeRequest, RequestMeta}
  alias InternalApi.Secrethub.SecretService.Stub

  defp url, do: Application.get_env(:notifications, :secrethub_endpoint)
  @opts [{:timeout, 30_000}]
  @secret_name "WEBHOOK_SECRET"

  def get(org_id, secret_name) when is_binary(secret_name) and secret_name != "" do
    meta = RequestMeta.new(org_id: org_id)
    req = DescribeRequest.new(metadata: meta, name: secret_name)

    {:ok, channel} = GRPC.Stub.connect(url())

    channel
    |> Stub.describe(req, @opts)
    |> response_to_map()
    |> process_status(org_id, secret_name)
    |> extract_secret(org_id, secret_name)
  end

  def get(_, _), do: {:ok, nil}

  defp extract_secret({:ok, %{data: %{env_vars: vars}}}, org_id, secret_name) do
    case Enum.find_value(vars, fn var -> if var.name == @secret_name, do: var.value end) do
      nil ->
        Logger.info(
          "Secrethub responded to Describe with :not_found org_id: #{org_id} secret_name: #{secret_name}"
        )

        {:ok, nil}

      secret ->
        {:ok, secret}
    end
  end

  defp extract_secret({:ok, nil}, _, _), do: {:ok, nil}

  defp extract_secret(error = {:error, _msg}, _, _), do: error

  defp process_status({:ok, map}, org_id, secret_name) do
    case map |> Map.get(:metadata, %{}) |> Map.get(:status, %{}) |> Map.get(:code) do
      :OK ->
        map |> Map.get(:secret) |> ToTuple.ok()

      :NOT_FOUND ->
        Logger.info(
          "Secrethub responded to Describe with :not_found org_id: #{org_id} secret_name: #{secret_name}"
        )

        {:ok, nil}

      _ ->
        log_invalid_response(map, org_id, secret_name)
    end
  end

  defp process_status(error = {:error, msg}, org_id, secret_name) do
    Watchman.increment("notification.secrethub.error")

    Logger.error(
      "Secrethub responded to Describe with :error org_id: #{org_id} secret_name: #{secret_name} message: #{inspect(msg)}"
    )

    error
  end

  defp response_to_map({:ok, response}),
    do: Proto.to_map(response, transformations: transformations())

  defp response_to_map(error = {:error, _msg}), do: error
  defp response_to_map(error), do: {:error, error}

  defp transformations do
    %{
      InternalApi.Secrethub.ResponseMeta.Code => {__MODULE__, :get_value},
      InternalApi.Secrethub.Secret.SecretLevel => {__MODULE__, :get_value},
      InternalApi.Secrethub.Secret.OrgConfig.ProjectsAccess => {__MODULE__, :get_value},
      InternalApi.Secrethub.Secret.OrgConfig.JobDebugAccess => {__MODULE__, :get_value},
      InternalApi.Secrethub.Secret.OrgConfig.JobAttachAccess => {__MODULE__, :get_value}
    }
  end

  def get_value(_name, value), do: value

  defp log_invalid_response(response, org_id, secret_name) do
    Logger.error(
      "Secrethub responded to Describe with :ok and invalid data: org_id: #{org_id} secret_name: #{secret_name} response: #{inspect(response)}"
    )

    response
    |> ToTuple.error()
  end
end
