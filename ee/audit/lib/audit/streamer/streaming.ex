defmodule Audit.Streamer do
  @moduledoc """
  This module provides a streaming interface for any Stream type (S3).
  """
  def check_access(stream, name) do
    check_access!(stream, name)
  rescue
    e -> {:error, e}
  end

  defp check_access!(stream = %InternalApi.Audit.Stream{}, name) do
    case stream.provider do
      :S3 ->
        rename(stream.s3_config)
        |> Audit.Streamer.Provider.S3.check_access(name)
    end
  end

  def cleanup(stream, name) do
    cleanup!(stream, name)
  rescue
    e -> {:error, e}
  end

  defp cleanup!(stream = %InternalApi.Audit.Stream{}, name) do
    case stream.provider do
      :S3 ->
        rename(stream.s3_config)
        |> Audit.Streamer.Provider.S3.delete_file(name)
    end
  end

  @doc """
  rename API names for key_id and key_secret to ExAws.S3 config
  """
  def rename(s3_config = %{type: :INSTANCE_ROLE}) when is_struct(s3_config) do
    Map.from_struct(s3_config)
    |> Map.new(&mapper/1)
  end

  def rename(s3_config = %{type: :INSTANCE_ROLE}) do
    Map.new(s3_config, &mapper/1)
  end

  def rename(s3_config = %{key_id: _, key_secret: _}) when is_struct(s3_config) do
    Map.from_struct(s3_config)
    |> Map.new(&mapper/1)
  end

  def rename(s3_config = %{key_id: _, key_secret: _}) do
    Map.new(s3_config, &mapper/1)
  end

  defp mapper({:key_id, id}), do: {:access_key_id, id}
  defp mapper({:key_secret, secret}), do: {:secret_access_key, secret}
  defp mapper({:bucket, bucket}), do: {:bucket_name, bucket}
  defp mapper(pair), do: pair

  def merge_config(s3_config = %{bucket_name: _}, _cridentials = %{type: "INSTANCE_ROLE"}),
    do: s3_config

  def merge_config(
        s3_config = %{bucket_name: _},
        cridentials = %{key_id: _, key_secret: _}
      ) do
    rename(cridentials)
    |> Map.merge(s3_config)
  end

  @doc """
  Log-safe summary of a provider error: tag, HTTP status and the provider's
  error code. Response bodies, messages and headers are never included.
  """
  def error_summary({:error, reason}), do: error_summary(reason)

  def error_summary({:http_error, status, response}) when is_integer(status),
    do: Enum.join(["http_error status=#{status}" | body_fields(response)], " ")

  def error_summary({tag, response}) when is_atom(tag),
    do: Enum.join([Atom.to_string(tag) | body_fields(response)], " ")

  def error_summary(%{__exception__: true, __struct__: module}),
    do: "exception #{inspect(module)}"

  def error_summary(%{reason: reason}) when is_atom(reason), do: "request_error reason=#{reason}"
  def error_summary(reason) when is_atom(reason), do: Atom.to_string(reason)
  def error_summary(_), do: "unknown_error"

  defp body_fields(%{body: body}) when is_binary(body) do
    case Regex.run(~r/<Code>([A-Za-z0-9._-]{1,64})<\/Code>/, body) do
      [_, code] -> ["code=#{code}"]
      _ -> []
    end
  end

  defp body_fields(_), do: []
end
