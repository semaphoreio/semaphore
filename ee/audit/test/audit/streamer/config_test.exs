defmodule Audit.Streamer.ConfigTest do
  use Support.DataCase

  test "creating stream configs" do
    org_id = Ecto.UUID.generate()
    t = Timex.shift(Timex.now(), days: -1)

    {:ok, stream} =
      Audit.Streamer.Config.create(%{
        org_id: org_id,
        provider: InternalApi.Audit.StreamProvider.value(:S3),
        metadata: %{
          bucket_name: "test-bucket"
        },
        cridentials: %{
          key_id: "key-id",
          key_secret: "the-cake-is-a-lie-secret"
        },
        status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
        last_streamed: t
      })

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id, stream_id: stream.id})

    assert config.org_id == org_id
    assert config.provider == :S3

    assert config.metadata == %{
             bucket_name: "test-bucket"
           }

    assert config.cridentials == stream.cridentials

    assert config.status == :ACTIVE
    assert Timex.compare(config.last_streamed, t, :seconds) == 0
  end

  test "creating stream configs using instance role" do
    org_id = Ecto.UUID.generate()
    t = Timex.shift(Timex.now(), days: -1)

    {:ok, stream} =
      Audit.Streamer.Config.create(%{
        org_id: org_id,
        provider: InternalApi.Audit.StreamProvider.value(:S3),
        metadata: %{
          bucket_name: "test-bucket",
          region: "us-east-1"
        },
        cridentials: %{
          type: "INSTANCE_ROLE"
        },
        status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
        last_streamed: t
      })

    {:ok, config} = Audit.Streamer.Config.get_one(%{org_id: org_id, stream_id: stream.id})

    assert config.org_id == org_id
    assert config.provider == :S3

    assert config.metadata == %{
             bucket_name: "test-bucket",
             region: "us-east-1"
           }

    assert config.cridentials == stream.cridentials

    assert config.status == :ACTIVE
    assert Timex.compare(config.last_streamed, t, :seconds) == 0
  end

  test "creating stream configs using internal hostname" do
    org_id = Ecto.UUID.generate()
    t = Timex.shift(Timex.now(), days: -1)

    {:error, error} =
      Audit.Streamer.Config.create(%{
        org_id: org_id,
        provider: InternalApi.Audit.StreamProvider.value(:S3),
        metadata: %{
          bucket_name: "test-bucket",
          host: "127.0.0.1"
        },
        status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
        last_streamed: t
      })

    assert error == "invalid host"
  end

  describe "creating stream configs with not authorized hostnames" do
    prohibited_uris = [
      "127.0.0.1",
      "172.16.0.2"
    ]

    for uri <- prohibited_uris do
      test "creating stream configs using host set to #{uri} fails" do
        org_id = Ecto.UUID.generate()
        t = Timex.shift(Timex.now(), days: -1)

        {:error, error} =
          Audit.Streamer.Config.create(%{
            org_id: org_id,
            provider: InternalApi.Audit.StreamProvider.value(:S3),
            metadata: %{
              bucket_name: "test-bucket",
              host: unquote(uri)
            },
            status: InternalApi.Audit.StreamStatus.value(:ACTIVE),
            last_streamed: t
          })

        assert error == "invalid host"
      end
    end
  end
end
