# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.JobRequestFactory.CacheTest do
  use Zebra.DataCase

  import ExUnit.CaptureLog

  alias Zebra.Workers.JobRequestFactory.Cache

  @org_id Ecto.UUID.generate()
  @cache_id Ecto.UUID.generate()
  @cache_credential "--BEGIN....lalalala...cache_key...END---"
  @cache_url "localhost:29920"
  @cache InternalApi.Cache.Cache.new(
           id: @cache_id,
           credential: @cache_credential,
           url: @cache_url
         )

  describe ".find" do
    test "with nil cache_id returns {:ok, nil} without contacting cachehub" do
      assert {:ok, nil} = Cache.find(nil, nil, @org_id)
    end

    test "logs warning and returns {:ok, nil} when cachehub returns non-OK status" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(
              code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM)
            )
        )
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "non-OK status"
      assert log =~ @cache_id
    end

    test "logs warning and returns {:ok, nil} when cachehub returns blank credential" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache: InternalApi.Cache.Cache.new(id: @cache_id, credential: " ", url: @cache_url)
        )
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "blank credential"
      assert log =~ @cache_id
      refute log =~ @cache_url
    end

    test "logs warning and returns {:ok, nil} when cachehub raises" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        raise "boom"
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "Failed to fetch info from cachehub"
      assert log =~ @cache_id
      refute log =~ @cache_credential
    end
  end

  describe ".env_vars" do
    test "cache_cli_parallel_archive_method is enabled => uses parallel archive method" do
      #
      # stubbed feature provider has feature disabled,
      # so we need to enable it here.
      #
      Mox.stub(Support.MockedProvider, :provide_features, fn _, _ ->
        features =
          Support.StubbedProvider.provide_features()
          |> case do
            {:ok, features} -> features
            {:error, _} -> []
          end
          |> Enum.map(fn
            %FeatureProvider.Feature{type: "cache_cli_parallel_archive_method"} = feature ->
              %{feature | quantity: 1, state: :enabled}

            feature ->
              feature
          end)

        {:ok, features}
      end)

      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @cache, @org_id)
      expected_envs = expected_envs(true)
      assert envs == expected_envs
    end

    test "cache_cli_parallel_archive_method is disabled => does not use parallel archive method" do
      {:ok, job} = Support.Factories.Job.create(:pending, %{})
      {:ok, envs} = Cache.env_vars(job, @cache, @org_id)
      expected_envs = expected_envs(false)
      assert envs == expected_envs
    end
  end

  defp expected_envs(new_method_enabled) do
    vars = [
      %{
        "name" => "SSH_PRIVATE_KEY_PATH",
        "value" => Base.encode64("/home/semaphore/.ssh/semaphore_cache_key")
      },
      %{
        "name" => "SEMAPHORE_CACHE_BACKEND",
        "value" => Base.encode64("sftp")
      },
      %{
        "name" => "SEMAPHORE_CACHE_PRIVATE_KEY_PATH",
        "value" => Base.encode64("/home/semaphore/.ssh/semaphore_cache_key")
      },
      %{
        "name" => "SEMAPHORE_CACHE_USERNAME",
        "value" => Base.encode64(String.replace(@cache_id, "-", ""))
      },
      %{
        "name" => "SEMAPHORE_CACHE_URL",
        "value" => Base.encode64("localhost:29920")
      }
    ]

    if new_method_enabled do
      vars ++
        [
          %{
            "name" => "SEMAPHORE_CACHE_ARCHIVE_METHOD",
            "value" => Base.encode64("native-parallel")
          }
        ]
    else
      vars
    end
  end
end
