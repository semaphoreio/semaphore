defmodule Audit.Streamer.Provider.S3Test do
  use Support.DataCase

  alias InternalApi, as: IA
  alias ExAws.S3

  test "localhost checking access" do
    ## good config
    {:ok, _} =
      Audit.Streamer.Provider.S3.check_access(
        %{
          access_key_id: "audit-key",
          secret_access_key: "the-cake-is-a-lie-secret",
          bucket_name: "test-bucket",
          host: System.fetch_env!("S3_HOST"),
          port: 9090,
          scheme: "http://"
        },
        "somefile"
      )
  end

  @doc """
  This test is disabled because adobe/s3mock does not have key/secret whitelist
  any secret you provide will work. test this using minio/minio.
  """
  @tag disabled: true
  test "localhost checking access with bad config" do
    {:error, _} =
      Audit.Streamer.Provider.S3.check_access(
        %{
          access_key_id: "wrong-key",
          secret_access_key: "wrong",
          bucket_name: "test-bucket",
          host: System.fetch_env!("S3_HOST"),
          port: 9090,
          scheme: "http://"
        },
        "test"
      )
  end

  test "localhost upload" do
    content = "test"

    config = %{
      access_key_id: "audit-key",
      secret_access_key: "the-cake-is-a-lie-secret",
      bucket_name: "test-bucket",
      host: System.fetch_env!("S3_HOST"),
      port: 9090,
      scheme: "http://"
    }

    Audit.Streamer.Provider.S3.upload(content, config, "test")

    ## S3 get object to verify content
    %{body: uploaded_body} =
      ExAws.S3.get_object(config.bucket_name, "test")
      |> ExAws.request!(config)

    assert uploaded_body == content

    cleanup(config)
  end

  defp cleanup(config) do
    S3.delete_object(config.bucket_name, "test")
    |> ExAws.request(config)
  end
end
