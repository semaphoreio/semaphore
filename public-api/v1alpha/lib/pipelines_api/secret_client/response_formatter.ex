defmodule PipelinesAPI.SecretClient.ResponseFormatter do
  @moduledoc """
  Module is used for parsing response from SecretHub service.
  """

  alias PipelinesAPI.Util.ToTuple

  @on_load :load_atoms

  def load_atoms() do
    [
      InternalApi.Secrethub.ResponseMeta.Code
    ]
    |> Enum.each(&Code.ensure_loaded/1)
  end

  def process_key_response(response), do: process_key_response_(response)

  defp process_key_response_({:ok, key_response}) do
    Util.Proto.to_map(key_response)
  end

  defp process_key_response_({:error, response}), do: {:error, response}

  defp process_key_response_(_error), do: ToTuple.internal_error("internal error")

  def process_describe_response({:ok, response}) do
    case Util.Proto.to_map(response) do
      {:ok, response_map} ->
        process_describe_response_(response_map)

      {:error, _} ->
        ToTuple.internal_error("bad response")
    end
  end

  def process_describe_response({:error, reason}), do: {:error, reason}

  def process_describe_response(_error), do: ToTuple.internal_error("internal error")

  defp process_describe_response_(%{metadata: %{status: %{code: :OK}}, secret: %{data: data}})
       when is_map(data) do
    with env_vars <- Map.get(data, :env_vars, []),
         files <- Map.get(data, :files, []) do
      {:ok, %{env_vars: env_vars, files: files}}
    end
  end

  defp process_describe_response_(%{metadata: %{status: %{code: :OK}}, secret: %{data: _data}}),
    do: ToTuple.user_error("secret data in unexpected format")

  defp process_describe_response_(%{metadata: %{status: %{code: :NOT_FOUND, message: message}}}),
    do: {:ok, %{env_vars: [], files: []}}

  defp process_describe_response_(%{
         metadata: %{status: %{code: :FAILED_PRECONDITION, message: message}}
       }),
       do: message |> ToTuple.user_error()

  defp process_describe_response_(%{metadata: %{status: %{code: :FAILED_PRECONDITION}}}),
    do: "request preconditions failed" |> ToTuple.user_error()

  defp process_describe_response_(_), do: ToTuple.internal_error("internal error")
end
