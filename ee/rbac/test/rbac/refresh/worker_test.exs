defmodule Rbac.Refresh.WorkerTest do
  use Rbac.RepoCase, async: false

  alias __MODULE__.{ProjectAPIStub, RepositoryAPIStub}

  setup do
    {:ok, project_api} = ProjectAPIStub.start_link()
    {:ok, repo_api} = RepositoryAPIStub.start_link()
    {:ok, worker} = Rbac.Refresh.Worker.start_link()

    on_exit(fn ->
      Process.exit(project_api, :kill)
      Process.exit(repo_api, :kill)
      Process.exit(worker, :kill)
    end)
  end

  describe "processing a refresh request" do
    test "it is able to process one refresh request" do
      request = create_request(0)

      work()

      assert reload(request).state == :done
    end

    test "it is able to process multiple refresh requests" do
      requests = Enum.map(1..10, fn _ -> create_request() end)

      work()

      Enum.each(requests, fn request ->
        assert reload(request).state == :done
      end)
    end

    test "on failure it returns only unprocessed projects to the list" do
      request = create_request()
      project_count = length(request.remaining_project_ids)

      RepositoryAPIStub.fail_after(3, :requests)

      work()

      request = reload(request)

      assert project_count - 3 == length(request.remaining_project_ids)
      assert request.state == :pending
    end

    test "it marks requests with no projects as done" do
      request = create_request()

      work()

      :timer.sleep(150)
      assert reload(request).state == :done
    end
  end

  def create_request(project_count \\ 10) do
    org_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    projects = times(project_count, &__MODULE__.ProjectAPIStub.create_project/0)
    project_id_list = Enum.map(projects, fn p -> p.metadata.id end)

    request = Rbac.Repo.CollaboratorRefreshRequest.new(org_id, project_id_list, user_id)

    {:ok, req} = Rbac.Repo.insert(request)

    req
  end

  defp times(n, fun, acc \\ []) do
    if n > 0 do
      times(n - 1, fun, acc ++ [fun.()])
    else
      acc
    end
  end

  defp work do
    Rbac.Refresh.Worker.perform_now()
    :timer.sleep(1500)
  end

  defp reload(request) do
    Rbac.Repo.CollaboratorRefreshRequest.load(request.id)
  end

  #
  # Various stubbign utilities
  #

  defmodule ProjectAPIStub do
    use Agent

    def start_link do
      GrpcMock.stub(ProjecthubMock, :describe, &__MODULE__.describe/2)

      Agent.start_link(fn -> %{projects: []} end, name: __MODULE__)
    end

    def create_project do
      project = Support.Factories.project(id: Ecto.UUID.generate())

      update(fn state -> %{state | projects: state.projects ++ [project]} end)

      project
    end

    def describe(req, _) do
      get(fn state ->
        alias InternalApi.Projecthub.DescribeResponse

        project = Enum.find(state.projects, fn project -> project.metadata.id == req.id end)

        %DescribeResponse{metadata: Support.Factories.response_meta(), project: project}
      end)
    end

    def get, do: Agent.get(__MODULE__, fn s -> s end)
    def get(fun), do: Agent.get(__MODULE__, fun)
    def update(fun), do: Agent.update(__MODULE__, fun)
  end

  defmodule RepositoryAPIStub do
    use Agent

    @almost_infinity 100_000_000

    def start_link do
      GrpcMock.stub(RepositoryMock, :list_collaborators, &__MODULE__.list_collaborators/2)

      Agent.start_link(fn -> %{req_count: 0, fail_after: @almost_infinity} end, name: __MODULE__)
    end

    def fail_after(n, :requests) do
      update(fn state -> %{state | fail_after: n} end)
    end

    def list_collaborators(_, _) do
      alias InternalApi.Repository.ListCollaboratorsResponse, as: Response

      inc_req_count()

      if should_fail?() do
        raise "AAA"
      else
        %Response{}
      end
    end

    def should_fail? do
      get(fn state -> state.req_count > state.fail_after end)
    end

    def inc_req_count do
      update(fn state -> %{state | req_count: state.req_count + 1} end)
    end

    def get, do: Agent.get(__MODULE__, fn s -> s end)
    def get(fun), do: Agent.get(__MODULE__, fun)
    def update(fun), do: Agent.update(__MODULE__, fun)
  end
end
