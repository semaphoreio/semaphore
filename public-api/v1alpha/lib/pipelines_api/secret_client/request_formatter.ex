defmodule PipelinesAPI.SecretClient.RequestFormatter do
  @moduledoc """
  Module serves to format data received from API client via HTTP into protobuf
  messages suitable for gRPC communication with SecretHub service.
  """

  alias Plug.Conn
  alias PipelinesAPI.Util.ToTuple

  alias InternalApi.Secrethub.{
    GetKeyRequest,
    DescribeRequest
  }

  # Secret Hub requests

  # forms GetKey request
  def form_key_request() do
    %{}
    |> Util.Proto.deep_new(GetKeyRequest)
  end

  # forms Describe request for deployment targets
  def form_describe_request(_params = %{"target_id" => target_id}, conn),
    do: form_describe_request_(target_id, conn)

  def form_describe_request(_params = %{"id" => target_id}, conn),
    do: form_describe_request_(target_id, conn)

  def form_describe_request(_params, _conn),
    do: ToTuple.user_error("deployment target id (target_id) must be provided")

  defp form_describe_request_(target_id, conn) do
    case target_id do
      nil ->
        ToTuple.user_error("deployment target id (target_id) must be provided")

      target_id ->
        %{
          deployment_target_id: target_id,
          secret_level: :DEPLOYMENT_TARGET,
          metadata: %{
            user_id: Conn.get_req_header(conn, "x-semaphore-user-id") |> Enum.at(0),
            org_id: Conn.get_req_header(conn, "x-semaphore-org-id") |> Enum.at(0)
          }
        }
        |> Util.Proto.deep_new(DescribeRequest)
    end
  end
end
