defmodule RepositoryHub.Server.Github.CreateBuildStatusActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CreateBuildStatusAction
  alias RepositoryHub.{InternalApiFactory, GithubClientFactory, RepositoryModelFactory}
  alias RepositoryHub.{CheckRunCache, GithubAppId, GithubChecksClient, GithubClient}

  import Mock

  setup do
    CheckRunCache.clear()
    [github_repo, githubapp_repo, bitbucket_repo | _] = RepositoryModelFactory.seed_repositories()

    %{github_repo: github_repo, githubapp_repo: githubapp_repo, bitbucket_repo: bitbucket_repo}
  end

  describe "Github oauth CreateBuildStatusAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:github_repo],
        adapter: Adapters.github_oauth()
      }
    end

    test "should create a build status", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      result = CreateBuildStatusAction.execute(adapter, request)

      assert {:ok, _response} = result
    end
  end

  describe "Github app CreateBuildStatusAction" do
    setup_with_mocks(GithubClientFactory.mocks(), context) do
      %{
        repository: context[:githubapp_repo],
        adapter: Adapters.github_app()
      }
    end

    test "should create a build status", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      result = CreateBuildStatusAction.execute(adapter, request)

      assert {:ok, _response} = result
    end

    test "should validate a request", %{adapter: adapter, repository: repository} do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)
      assert {:ok, _} = CreateBuildStatusAction.validate(adapter, request)

      invalid_assertions = [
        repository_id: "",
        repository_id: "not an uuid",
        commit_sha: "",
        commit_sha: "not a sha",
        status: "",
        status: "not a status",
        status: 1,
        url: "",
        url: "not url",
        description: "",
        context: ""
      ]

      for {key, invalid_value} <- invalid_assertions do
        request = Map.put(request, key, invalid_value)
        assert {:error, _} = CreateBuildStatusAction.validate(adapter, request)
      end
    end

    test "flag ON + PENDING, no existing run → creates in_progress", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING
        )
        |> Map.put(:source_id, "ppl-1")

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn params, _opts ->
             assert params.external_id == "semaphore:ppl-1"
             assert params.app_id == "90709"
             {:error, %{status: GRPC.Status.not_found(), message: "not found"}}
           end,
           create_check_run: fn params, _opts ->
             assert params.external_id == "semaphore:ppl-1"
             assert params.status == "in_progress"
             assert params.output == %{title: request.description, summary: request.description}
             assert params.name == request.context
             assert params.head_sha == request.commit_sha
             {:ok, %{"id" => 1}}
           end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubChecksClient.find_check_run(:_, :_))
        assert called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
        refute called(GithubClient.create_build_status(:_, :_))
      end
    end

    test "flag ON + PENDING, existing in_progress run → updates it (no create)", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING
        )

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts ->
             {:ok, %{"id" => 5, "status" => "in_progress"}}
           end,
           update_check_run: fn params, _opts ->
             assert params.check_run_id == 5
             assert params.status == "in_progress"
             {:ok, %{"id" => 5, "status" => "in_progress"}}
           end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubChecksClient.find_check_run(:_, :_))
        assert called(GithubChecksClient.update_check_run(:_, :_))
        refute called(GithubChecksClient.create_check_run(:_, :_))
      end
    end

    test "flag ON + PENDING after this pipeline's run completed → stale, no write", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING,
          source_id: "ppl-1"
        )

      with_mocks([
        {Watchman, [:passthrough], []},
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn params, _opts ->
             assert params.external_id == "semaphore:ppl-1"
             {:ok, %{"id" => 5, "status" => "completed", "conclusion" => "success"}}
           end,
           create_check_run: fn _params, _opts -> {:ok, %{"id" => 6}} end,
           update_check_run: fn _params, _opts -> {:ok, %{"id" => 5}} end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        refute called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
        refute called(GithubClient.create_build_status(:_, :_))
        assert called(Watchman.increment("set_check_run.skipped_stale_pending"))
      end
    end

    test "flag ON + PENDING without source_id, existing completed run → creates fresh (no un-complete)", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING
        )

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts ->
             {:ok, %{"id" => 5, "status" => "completed"}}
           end,
           create_check_run: fn params, _opts ->
             assert params.status == "in_progress"
             {:ok, %{"id" => 6}}
           end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubChecksClient.find_check_run(:_, :_))
        assert called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
      end
    end

    test "flag ON + SUCCESS, existing run → updates to completed/success", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :SUCCESS
        )

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts ->
             {:ok, %{"id" => 7, "status" => "in_progress"}}
           end,
           update_check_run: fn params, _opts ->
             assert params.status == "completed"
             assert params.conclusion == "success"
             assert params.check_run_id == 7
             assert params.output == %{title: request.description, summary: request.description}
             {:ok, %{"id" => 7, "conclusion" => "success"}}
           end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubChecksClient.find_check_run(:_, :_))
        assert called(GithubChecksClient.update_check_run(:_, :_))
        refute called(GithubChecksClient.create_check_run(:_, :_))
      end
    end

    test "flag ON + SUCCESS, no existing run → creates completed", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :SUCCESS
        )

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:error, %{status: GRPC.Status.not_found(), message: "not found"}} end,
           create_check_run: fn params, _opts ->
             assert params.status == "completed"
             assert params.conclusion == "success"
             {:ok, %{"id" => 9}}
           end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubChecksClient.find_check_run(:_, :_))
        assert called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
      end
    end

    test "flag OFF → legacy status only", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)

      with_mocks([
        {FeatureProvider, [], [find_feature: fn _, _ -> {:ok, checks_api_feature(false)} end]},
        {GithubChecksClient, [],
         [
           create_check_run: fn _params, _opts -> {:ok, %{}} end,
           find_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end,
           update_check_run: fn _params, _opts -> {:ok, %{}} end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubClient.create_build_status(:_, :_))
        refute called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.find_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
      end
    end

    test "flag not registered → legacy status only", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)

      with_mocks([
        {FeatureProvider, [], [find_feature: fn type, _ -> {:error, {:not_found, type}} end]},
        {GithubChecksClient, [], [find_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubClient.create_build_status(:_, :_))
        refute called(GithubChecksClient.find_check_run(:_, :_))
      end
    end

    test "flag can't be evaluated → fails as unavailable without writing", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)

      with_mocks([
        {Watchman, [:passthrough], []},
        {FeatureProvider, [], [find_feature: fn _, _ -> {:error, %GRPC.RPCError{status: 14}} end]},
        {GithubChecksClient, [], [find_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end]}
      ]) do
        assert {:error, %{status: status}} = CreateBuildStatusAction.execute(adapter, request)
        assert status == GRPC.Status.unavailable()
        refute called(GithubClient.create_build_status(:_, :_))
        refute called(GithubChecksClient.find_check_run(:_, :_))
        assert called(Watchman.increment("set_check_run.flag_unavailable"))
      end
    end

    test "flag provider fails behind the cache → fails as unavailable without writing", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id)

      # The real FeatureProvider + CachexCache stack turns a provider error
      # into {:not_found, {:provide_features, org_id}}, not the provider's error.
      provider = Application.get_env(FeatureProvider, :provider)

      Application.put_env(
        FeatureProvider,
        :provider,
        {__MODULE__.UnavailableFeatureProvider,
         [cache: {FeatureProvider.CachexCache, name: :feature_provider_cache, ttl_ms: :timer.minutes(10)}]}
      )

      on_exit(fn -> Application.put_env(FeatureProvider, :provider, provider) end)
      Cachex.clear(:feature_provider_cache)

      with_mocks([
        {GithubChecksClient, [], [find_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end]}
      ]) do
        assert {:error, %{status: status}} = CreateBuildStatusAction.execute(adapter, request)
        assert status == GRPC.Status.unavailable()
        refute called(GithubClient.create_build_status(:_, :_))
        refute called(GithubChecksClient.find_check_run(:_, :_))
      end
    end

    test "checks client error fails the action", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING
        )

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:error, %{status: GRPC.Status.not_found(), message: "not found"}} end,
           create_check_run: fn _params, _opts ->
             {:error, %{status: 500, message: "x"}}
           end
         ]}
      ]) do
        assert {:error, _} = CreateBuildStatusAction.execute(adapter, request)
      end
    end

    test "flag ON, installation lacks the Checks permission → falls back to commit status", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id, status: :PENDING)

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts ->
             {:error, %{status: GRPC.Status.permission_denied(), message: "missing Checks permission"}}
           end,
           create_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end,
           update_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert called(GithubClient.create_build_status(:_, :_))
        refute called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
      end
    end

    test "flag ON, rate limited lookup → fails without writing", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id, status: :PENDING)

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:error, :rate_limit} end,
           create_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end,
           update_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end
         ]}
      ]) do
        assert {:error, :rate_limit} = CreateBuildStatusAction.execute(adapter, request)
        refute called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
        refute called(GithubClient.create_build_status(:_, :_))
      end
    end

    test "flag ON, GitHub App id can't be resolved → fails without looking up or writing", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id, status: :PENDING)

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubAppId, [],
         [get: fn -> {:error, %{status: GRPC.Status.unavailable(), message: "Can't fetch the GitHub App id"}} end]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:ok, %{"id" => 1, "status" => "in_progress"}} end,
           create_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end,
           update_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end
         ]}
      ]) do
        assert {:error, %{status: status}} = CreateBuildStatusAction.execute(adapter, request)
        assert status == GRPC.Status.unavailable()
        refute called(GithubChecksClient.find_check_run(:_, :_))
        refute called(GithubChecksClient.create_check_run(:_, :_))
        refute called(GithubChecksClient.update_check_run(:_, :_))
        refute called(GithubClient.create_build_status(:_, :_))
      end
    end

    test "flag ON, the pipeline's run is cached → later statuses update it without a lookup", %{
      adapter: adapter,
      repository: repository
    } do
      pending =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING,
          source_id: "ppl-1"
        )

      with_mocks([
        {Watchman, [:passthrough], []},
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:error, %{status: GRPC.Status.not_found(), message: "not found"}} end,
           create_check_run: fn _params, _opts -> {:ok, %{"id" => 11, "status" => "in_progress"}} end,
           update_check_run: fn params, _opts ->
             assert params.check_run_id == 11
             {:ok, %{"id" => 11, "status" => params.status}}
           end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, pending)
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, pending)
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, %{pending | status: :SUCCESS})

        assert_called_exactly(GithubChecksClient.find_check_run(:_, :_), 1)
        assert_called_exactly(GithubChecksClient.create_check_run(:_, :_), 1)
        assert_called_exactly(GithubChecksClient.update_check_run(:_, :_), 2)
        assert called(Watchman.increment("set_check_run.cache_hit"))

        # The cache now knows the run completed, so a stale PENDING is skipped.
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, pending)
        assert_called_exactly(GithubChecksClient.update_check_run(:_, :_), 2)
        assert called(Watchman.increment("set_check_run.skipped_stale_pending"))
      end
    end

    test "flag ON, a failed update of a cached run drops it → the retry looks the run up again", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING,
          source_id: "ppl-1"
        )

      CheckRunCache.put(CheckRunCache.key(request, repository), 11, "in_progress")

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:ok, %{"id" => 12, "status" => "in_progress"}} end,
           update_check_run: fn
             %{check_run_id: 11}, _opts -> {:error, %{status: GRPC.Status.failed_precondition(), message: "Not Found"}}
             %{check_run_id: 12}, _opts -> {:ok, %{"id" => 12, "status" => "in_progress"}}
           end
         ]}
      ]) do
        assert {:error, _} = CreateBuildStatusAction.execute(adapter, request)
        refute called(GithubChecksClient.find_check_run(:_, :_))

        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert_called_exactly(GithubChecksClient.find_check_run(:_, :_), 1)
        assert {:ok, %{"id" => 12}} = CheckRunCache.get(CheckRunCache.key(request, repository))
      end
    end

    test "flag ON, a request without source_id is never cached", %{
      adapter: adapter,
      repository: repository
    } do
      request = InternalApiFactory.create_build_status_request(repository_id: repository.id, status: :PENDING)

      with_mocks([
        {FeatureProvider, [],
         [
           find_feature: fn :github_checks_api, [param: org_id] ->
             {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
           end
         ]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:ok, %{"id" => 5, "status" => "in_progress"}} end,
           update_check_run: fn _params, _opts -> {:ok, %{"id" => 5, "status" => "in_progress"}} end
         ]}
      ]) do
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert {:ok, _} = CreateBuildStatusAction.execute(adapter, request)
        assert_called_exactly(GithubChecksClient.find_check_run(:_, :_), 2)
      end
    end

    for status <- [:PENDING, :SUCCESS] do
      test "flag ON + #{status}, lookup fails (not a not_found) → fails without writing", %{
        adapter: adapter,
        repository: repository
      } do
        request =
          InternalApiFactory.create_build_status_request(
            repository_id: repository.id,
            status: unquote(status)
          )

        with_mocks([
          {FeatureProvider, [],
           [
             find_feature: fn :github_checks_api, [param: org_id] ->
               {:ok, checks_api_feature(org_id == RepositoryHub.Stub.ProjectHub.org_id())}
             end
           ]},
          {GithubChecksClient, [],
           [
             find_check_run: fn _params, _opts ->
               {:error, %{status: GRPC.Status.unavailable(), message: "GitHub Checks API find_check_run failed"}}
             end,
             create_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end,
             update_check_run: fn _params, _opts -> {:ok, %{"id" => 1}} end
           ]}
        ]) do
          assert {:error, %{status: status}} = CreateBuildStatusAction.execute(adapter, request)
          assert status == GRPC.Status.unavailable()
          refute called(GithubChecksClient.create_check_run(:_, :_))
          refute called(GithubChecksClient.update_check_run(:_, :_))
        end
      end
    end
  end

  describe "Universal CreateBuildStatusAction" do
    test "should fail" do
      assert_raise Protocol.UndefinedError, fn ->
        request = InternalApiFactory.create_build_status_request()
        CreateBuildStatusAction.execute(Adapters.universal(), request)
      end
    end
  end

  defp checks_api_feature(enabled?) do
    %FeatureProvider.Feature{type: "github_checks_api", state: if(enabled?, do: :enabled, else: :disabled)}
  end

  defmodule UnavailableFeatureProvider do
    use FeatureProvider.Provider

    @impl FeatureProvider.Provider
    def provide_features(_org_id, _opts), do: {:error, %GRPC.RPCError{status: GRPC.Status.unavailable()}}

    @impl FeatureProvider.Provider
    def provide_machines(_org_id, _opts), do: {:ok, []}
  end
end
