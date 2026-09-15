defmodule Front.ProjectPage.ModelTest do
  use ExUnit.Case

  import Mock

  alias Front.ProjectPage.Model
  alias Front.ProjectPage.Model.LoadParams

  describe "load_from_api" do
    setup do
      Support.FakeServices.stub_responses()
    end

    test "returns data collected from APIs" do
      params =
        struct!(LoadParams,
          project_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          organization_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          page_token: "dae0438b-4645-49a0-8254-19e4ea7b9f89",
          direction: "next",
          user_page?: false,
          ref_types: ["branch"]
        )

      {:ok, _data, :from_api} = Model.load_from_api(params)
    end

    test "returns degraded model when workflow list times out" do
      params =
        struct!(LoadParams,
          project_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          organization_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          page_token: "dae0438b-4645-49a0-8254-19e4ea7b9f89",
          direction: "next",
          user_page?: false,
          ref_types: ["branch"]
        )

      with_mock Front.Models.Workflow, [:passthrough],
        list_latest_workflows: fn _ -> {:error, :timeout} end do
        {:ok, data, :from_api} = Model.load_from_api(params)

        assert data.workflows == []
        assert data.workflow_fetch_error =~ "Loading workflows timed out"
      end
    end

    test "returns degraded model when keyset workflow fetch fails" do
      params =
        struct!(LoadParams,
          project_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          organization_id: "2e4ca2aa-ab16-4eb7-924d-0d698f7ca555",
          page_token: "",
          direction: "next",
          list_mode: "all_pipelines",
          user_page?: false,
          ref_types: ["pr"]
        )

      rpc_error = %GRPC.RPCError{status: 2, message: "Internal Server Error"}

      with_mock Front.Models.Workflow, [:passthrough],
        list_keyset: fn _ -> {:error, rpc_error} end do
        {:ok, data, :from_api} = Model.load_from_api(params)

        assert data.workflows == []
        assert data.workflow_fetch_error =~ "couldn't load workflows"
      end
    end
  end

  describe "cache_key" do
    test "constructs cache key based on parameters" do
      params =
        struct!(LoadParams,
          project_id: "1",
          organization_id: "2",
          page_token: "4",
          direction: "next",
          user_page?: true,
          ref_types: ["branch", "tag"]
        )

      assert Model.cache_key(params) ==
               "#{Model.cache_prefix()}/#{Model.cache_version()}/project_id=1/ref_types=branchtag/list_mode=latest/"
    end
  end

  describe "invalidate" do
    test "deletes the cache key" do
      params =
        struct!(LoadParams,
          project_id: "1",
          organization_id: "2",
          page_token: "4",
          direction: "next",
          user_page?: true,
          ref_types: ["branch", "tag"]
        )

      cache_key = params |> Model.cache_key()
      Cacheman.put(:front, cache_key, "content")

      assert {:ok, 1} = params |> Model.invalidate()
    end
  end

  describe "pins default branch" do
    setup do
      Cacheman.clear(:front)
      Support.Stubs.init()
      Support.Stubs.build_shared_factories()
      Support.Stubs.DB.clear(:workflows)

      user = Support.Stubs.User.default()
      organization = Support.Stubs.Organization.default()

      %{user: user, organization: organization}
    end

    test "moves the default branch to the front of page one", %{
      user: user,
      organization: organization
    } do
      project = create_project(organization, user)
      create_branch_workflow(project, user, "feature-a")
      create_branch_workflow(project, user, "main")
      create_branch_workflow(project, user, "feature-b")

      {:ok, data, :from_api} = Model.load_from_api(load_params(project, organization))

      assert Enum.map(data.workflows, & &1.branch_name) == ["main", "feature-a", "feature-b"]
    end

    test "prepends a stale default branch missing from the first page", %{
      user: user,
      organization: organization
    } do
      project = create_project(organization, user)
      feature = create_branch_workflow(project, user, "feature-a")
      main = create_branch_workflow(project, user, "main")

      with_mock Front.Models.Workflow, [:passthrough],
        list_latest_workflows: fn _params ->
          {[Front.Models.Workflow.find(feature.id)], "", ""}
        end,
        find_latest: fn _opts -> Front.Models.Workflow.find(main.id) end do
        {:ok, data, :from_api} = Model.load_from_api(load_params(project, organization))

        assert Enum.map(data.workflows, & &1.branch_name) == ["main", "feature-a"]
      end
    end

    test "leaves plumber order when find_latest returns nil", %{
      user: user,
      organization: organization
    } do
      project = create_project(organization, user)
      feature = create_branch_workflow(project, user, "feature-a")

      with_mock Front.Models.Workflow, [:passthrough],
        list_latest_workflows: fn _params ->
          {[Front.Models.Workflow.find(feature.id)], "", ""}
        end,
        find_latest: fn _opts -> nil end do
        {:ok, data, :from_api} = Model.load_from_api(load_params(project, organization))

        assert Enum.map(data.workflows, & &1.branch_name) == ["feature-a"]
      end
    end

    test "filters the default branch out of later pages", %{
      user: user,
      organization: organization
    } do
      project = create_project(organization, user)
      create_branch_workflow(project, user, "feature-a")
      create_branch_workflow(project, user, "main")
      create_branch_workflow(project, user, "feature-b")

      params =
        load_params(project, organization,
          page_token: "next-page",
          direction: "next"
        )

      {:ok, data, :from_api} = Model.load_from_api(params)

      assert Enum.map(data.workflows, & &1.branch_name) == ["feature-a", "feature-b"]
    end

    test "does not pin when the default branch is blank", %{
      user: user,
      organization: organization
    } do
      project = create_project(organization, user, repo_default_branch: "")
      create_branch_workflow(project, user, "feature-a")
      create_branch_workflow(project, user, "main")
      create_branch_workflow(project, user, "feature-b")

      {:ok, data, :from_api} = Model.load_from_api(load_params(project, organization))

      assert Enum.map(data.workflows, & &1.branch_name) == ["feature-a", "main", "feature-b"]
    end

    test "does not pin on non-branch tabs", %{user: user, organization: organization} do
      project = create_project(organization, user)
      create_branch_workflow(project, user, "feature-a")
      create_branch_workflow(project, user, "main")
      create_branch_workflow(project, user, "feature-b")

      params = load_params(project, organization, ref_types: ["pr"])
      {:ok, data, :from_api} = Model.load_from_api(params)

      assert Enum.map(data.workflows, & &1.branch_name) == ["feature-a", "main", "feature-b"]
    end

    test "does not change all_pipelines order", %{user: user, organization: organization} do
      project = create_project(organization, user)
      create_branch_workflow(project, user, "feature-a")
      create_branch_workflow(project, user, "main")
      create_branch_workflow(project, user, "feature-b")

      params = load_params(project, organization, list_mode: "all_pipelines")
      {:ok, data, :from_api} = Model.load_from_api(params)

      assert Enum.map(data.workflows, & &1.branch_name) == ["feature-a", "main", "feature-b"]
    end

    defp load_params(project, organization, opts \\ []) do
      struct!(
        LoadParams,
        [
          project_id: project.id,
          organization_id: organization.id,
          page_token: "",
          direction: "next",
          list_mode: "latest",
          user_page?: false,
          ref_types: ["branch"]
        ]
        |> Keyword.merge(opts)
      )
    end

    defp create_project(organization, user, opts \\ []) do
      Support.Stubs.Project.create(
        organization,
        user,
        Keyword.merge(
          [
            repo_default_branch: "main",
            run_on: ["branches"],
            state: InternalApi.Projecthub.Project.Status.State.value(:READY)
          ],
          opts
        )
      )
    end

    defp create_branch_workflow(project, user, branch_name) do
      branch = Support.Stubs.Branch.create(project, name: branch_name, display_name: branch_name)
      hook = Support.Stubs.Hook.create(branch)
      workflow = Support.Stubs.Workflow.create(hook, user)
      Support.Stubs.Pipeline.create_initial(workflow)
      workflow
    end
  end
end
