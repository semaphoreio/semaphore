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
end
