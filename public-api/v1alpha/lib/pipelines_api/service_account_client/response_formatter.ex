defmodule PipelinesAPI.ServiceAccountClient.ResponseFormatter do
  @moduledoc false
  def process_create_response({:ok, response}) do
    {:ok,
     %{
       service_account: serialize(response.service_account),
       api_token: response.api_token
     }}
  end

  def process_create_response(error), do: error

  def process_list_response({:ok, response}) do
    service_accounts = Enum.map(response.service_accounts, &serialize/1)

    {:ok,
     %{
       service_accounts: service_accounts,
       next_page_token: response.next_page_token
     }}
  end

  def process_list_response(error), do: error

  def process_describe_response({:ok, response}) do
    {:ok, serialize(response.service_account)}
  end

  def process_describe_response(error), do: error

  def process_update_response({:ok, response}) do
    {:ok, serialize(response.service_account)}
  end

  def process_update_response(error), do: error

  def process_destroy_response({:ok, _response}), do: {:ok, %{status: "deleted"}}
  def process_destroy_response(error), do: error

  def process_deactivate_response({:ok, _response}), do: {:ok, %{status: "deactivated"}}
  def process_deactivate_response(error), do: error

  def process_reactivate_response({:ok, _response}), do: {:ok, %{status: "reactivated"}}
  def process_reactivate_response(error), do: error

  def process_regenerate_token_response({:ok, response}) do
    {:ok, %{api_token: response.api_token}}
  end

  def process_regenerate_token_response(error), do: error

  defp serialize(sa) do
    %{
      id: sa.id,
      name: sa.name,
      description: sa.description,
      org_id: sa.org_id,
      creator_id: sa.creator_id,
      created_at: timestamp_to_seconds(sa.created_at),
      updated_at: timestamp_to_seconds(sa.updated_at),
      deactivated: sa.deactivated
    }
  end

  defp timestamp_to_seconds(%{seconds: 0}), do: nil
  defp timestamp_to_seconds(%{seconds: seconds}), do: seconds
  defp timestamp_to_seconds(_), do: nil
end
