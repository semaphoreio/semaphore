defmodule RepositoryHub.Server.Github.CreateBuildStatusActionTest do
  @moduledoc false
  use RepositoryHub.ServerActionCase, async: false

  alias RepositoryHub.Adapters
  alias RepositoryHub.Server.CreateBuildStatusAction
  alias RepositoryHub.{InternalApiFactory, GithubClientFactory, RepositoryModelFactory}
  alias RepositoryHub.{GithubChecksClient, GithubClient}

  import Mock

  setup do
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

      with_mocks([
        {FeatureProvider, [], [feature_enabled?: fn _, _ -> true end]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:error, %{message: "not found"}} end,
           create_check_run: fn params, _opts ->
             assert params.status == "in_progress"
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
        {FeatureProvider, [], [feature_enabled?: fn _, _ -> true end]},
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

    test "flag ON + PENDING, existing completed run (rebuild) → creates fresh (no un-complete)", %{
      adapter: adapter,
      repository: repository
    } do
      request =
        InternalApiFactory.create_build_status_request(
          repository_id: repository.id,
          status: :PENDING
        )

      with_mocks([
        {FeatureProvider, [], [feature_enabled?: fn _, _ -> true end]},
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
        {FeatureProvider, [], [feature_enabled?: fn _, _ -> true end]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts ->
             {:ok, %{"id" => 7, "status" => "in_progress"}}
           end,
           update_check_run: fn params, _opts ->
             assert params.status == "completed"
             assert params.conclusion == "success"
             assert params.check_run_id == 7
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
        {FeatureProvider, [], [feature_enabled?: fn _, _ -> true end]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:error, %{message: "not found"}} end,
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
        {FeatureProvider, [], [feature_enabled?: fn _, _ -> false end]},
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
        {FeatureProvider, [], [feature_enabled?: fn _, _ -> true end]},
        {GithubChecksClient, [],
         [
           find_check_run: fn _params, _opts -> {:error, %{message: "not found"}} end,
           create_check_run: fn _params, _opts ->
             {:error, %{status: 500, message: "x"}}
           end
         ]}
      ]) do
        assert {:error, _} = CreateBuildStatusAction.execute(adapter, request)
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
end
