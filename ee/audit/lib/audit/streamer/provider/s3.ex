defmodule Audit.Streamer.Provider.S3 do
  alias ExAws.S3
  require Logger

  def upload(content, config, file_name) do
    S3.put_object(config.bucket_name, file_name, content)
    |> ExAws.request(create_config(config))
  end

  def check_file(config, file_name) do
    S3.head_object(config.bucket_name, file_name)
    |> ExAws.request(create_config(config))
  end

  def check_access(config, name) do
    S3.put_object(config.bucket_name, name, "test")
    |> ExAws.request(create_config(config))
  end

  def delete_file(config, file_name) do
    S3.delete_object(config.bucket_name, file_name)
    |> ExAws.request(create_config(config))
  end

  defp create_config(
         config = %{access_key_id: key, secret_access_key: secret, host: host, region: region}
       )
       when is_binary(host) and host != "" do
    if host == "s3.amazonaws.com" and region != "" do
      [access_key_id: key, secret_access_key: secret, region: region]
    else
      Map.to_list(config)
    end
  end

  defp create_config(%{access_key_id: key, secret_access_key: secret, host: "", region: region}) do
    [access_key_id: key, secret_access_key: secret, region: region]
  end

  defp create_config(config = %{access_key_id: _key, secret_access_key: _secret}) do
    Map.to_list(config)
  end

  defp create_config(_config = %{region: region}), do: [region: region]
end
