# credo:disable-for-this-file Credo.Check.Design.DuplicatedCode
defmodule Zebra.Workers.JobRequestFactory.CacheTest do
  use Zebra.DataCase

  import ExUnit.CaptureLog

  alias Zebra.Workers.JobRequestFactory.Cache
  alias InternalApi.ResponseStatus

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

    test "treats an empty-string credential as blank => returns {:ok, nil}" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          cache: InternalApi.Cache.Cache.new(id: @cache_id, credential: "", url: @cache_url)
        )
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Cache.find(@cache_id, nil, @org_id)
        end)

      assert log =~ "blank credential"
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

  describe ".forked_pr?" do
    test "true when PR slug org differs from repo slug org" do
      repo =
        InternalApi.RepoProxy.Hook.new(
          repo_slug: "test-org/test-repo",
          pr_slug: "fork-org/test-repo"
        )

      assert Cache.forked_pr?(repo)
    end

    test "false when PR slug org matches repo slug org" do
      repo =
        InternalApi.RepoProxy.Hook.new(
          repo_slug: "test-org/test-repo",
          pr_slug: "test-org/test-repo"
        )

      refute Cache.forked_pr?(repo)
    end

    test "false when there is no PR slug (not a PR build)" do
      repo = InternalApi.RepoProxy.Hook.new(repo_slug: "test-org/test-repo", pr_slug: "")
      refute Cache.forked_pr?(repo)
    end

    test "false when repo proxy is nil" do
      refute Cache.forked_pr?(nil)
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

  describe ".find" do
    test "forked PR with disable_forked_pr_cache enabled skips cache loading" do
      enable_feature("disable_forked_pr_cache")

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        raise "cache should not be queried for forked pull requests"
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo"}

      assert Cache.find(@cache_id, repo, @org_id) == {:ok, nil}
    end

    test "approval enable-cache bypasses forked PR cache restriction" do
      enable_feature("disable_forked_pr_cache")

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn req, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          cache:
            InternalApi.Cache.Cache.new(
              id: req.cache_id,
              credential: "--BEGIN....lalalala...cache_key...END---",
              url: "localhost:29920"
            )
        )
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert {:ok, cache} = Cache.find(@cache_id, repo, @org_id)
      assert cache.id == @cache_id
    end

    test "debug job on forked PR skips cache even when approval enable-cache is set" do
      enable_feature("disable_forked_pr_cache")

      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn _, _ ->
        raise "cache should not be queried for debug jobs on forked pull requests"
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert Cache.find(@cache_id, repo, @org_id, :debug_job) == {:ok, nil}
    end

    test "debug job on forked PR uses cache when disable_forked_pr_cache is disabled" do
      GrpcMock.stub(Support.FakeServers.CacheApi, :describe, fn req, _ ->
        InternalApi.Cache.DescribeResponse.new(
          status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
          cache:
            InternalApi.Cache.Cache.new(
              id: req.cache_id,
              credential: "--BEGIN....lalalala...cache_key...END---",
              url: "localhost:29920"
            )
        )
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert {:ok, cache} = Cache.find(@cache_id, repo, @org_id, :debug_job)
      assert cache.id == @cache_id
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

  defp enable_feature(type) do
    Mox.stub(Support.MockedProvider, :provide_features, fn _, _ ->
      features =
        Support.StubbedProvider.provide_features()
        |> case do
          {:ok, features} -> features
          {:error, _} -> []
        end

      extra_feature = Support.StubbedProvider.feature(type, [:enabled])

      {:ok, [extra_feature | features]}
    end)
  end
end
