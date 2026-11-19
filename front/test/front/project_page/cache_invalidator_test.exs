defmodule Front.ProjectPage.CacheInvalidatorTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Support.Stubs
  alias Support.Stubs.DB

  alias Front.ProjectPage.CacheInvalidator
  alias Front.ProjectPage.Model

  @ref_types ["branch", "pr", "tag", ""]

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    project = DB.first(:projects)
    pipeline = DB.first(:pipelines)
    organization = DB.first(:organizations)

    [
      project: project,
      pipeline: pipeline,
      organization: organization
    ]
  end

  describe "pipeline_event" do
    test "invalidates project page caches for one git ref and all together", %{
      project: project,
      pipeline: pipeline
    } do
      branch_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=branch/list_mode=latest/"

      all_git_refs_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=/list_mode=latest/"

      Cacheman.put(
        :front,
        branch_cache_key,
        "test content"
      )

      Cacheman.put(
        :front,
        all_git_refs_cache_key,
        "test content"
      )

      assert Cacheman.exists?(:front, branch_cache_key)
      assert Cacheman.exists?(:front, all_git_refs_cache_key)

      InternalApi.Plumber.PipelineEvent.new(
        pipeline_id: pipeline.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Plumber.PipelineEvent.encode()
      |> CacheInvalidator.pipeline_event()

      refute Cacheman.exists?(:front, branch_cache_key)
      refute Cacheman.exists?(:front, all_git_refs_cache_key)
    end

    for {ref_type, git_ref_type} <- [{"pr", :PR}, {"tag", :TAG}] do
      test "invalidates the #{ref_type} list and the list of all git refs for a #{ref_type} hook",
           %{project: project} do
        pipeline =
          pipeline_with_hook(
            git_ref_type: InternalApi.RepoProxy.Hook.Type.value(unquote(git_ref_type))
          )

        put_all_cache_keys(project)

        pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()

        assert cached_ref_types(project) == @ref_types -- [unquote(ref_type), ""]
      end
    end

    test "invalidates only the list of all git refs when the pipeline has no hook yet", %{
      project: project
    } do
      pipeline = pipeline_without_hook()

      put_all_cache_keys(project)

      pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()

      assert cached_ref_types(project) == ["branch", "pr", "tag"]
    end

    test "invalidates only the list of all git refs when the hook is not found", %{
      project: project
    } do
      pipeline = pipeline_with_unknown_hook()

      put_all_cache_keys(project)

      pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()

      assert cached_ref_types(project) == ["branch", "pr", "tag"]
    end

    test "leaves project page caches alone when the project is not found", %{
      project: project
    } do
      pipeline = pipeline_with_unknown_project()

      put_all_cache_keys(project)

      log =
        capture_log(fn ->
          pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()
        end)

      assert log =~ "Project not found"
      assert cached_ref_types(project) == @ref_types
    end
  end

  describe "pipeline_event when the project page is preheated" do
    setup do
      previous = Application.get_env(:front, :preheat_project_page)
      Application.put_env(:front, :preheat_project_page, "true")

      on_exit(fn -> Application.put_env(:front, :preheat_project_page, previous) end)
    end

    test "refreshes the list for the hook's git ref and the list of all git refs", %{
      project: project,
      pipeline: pipeline
    } do
      put_all_cache_keys(project)

      pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()

      assert refreshed_ref_types(project) == ["branch", ""]
    end

    test "refreshes only the list of all git refs when the pipeline has no hook yet", %{
      project: project
    } do
      pipeline = pipeline_without_hook()

      put_all_cache_keys(project)

      pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()

      assert refreshed_ref_types(project) == [""]
    end

    test "refreshes only the list of all git refs when the hook is not found", %{
      project: project
    } do
      pipeline = pipeline_with_unknown_hook()

      put_all_cache_keys(project)

      pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()

      assert refreshed_ref_types(project) == [""]
    end

    test "leaves project page caches alone when the project is not found", %{
      project: project
    } do
      pipeline = pipeline_with_unknown_project()

      put_all_cache_keys(project)

      capture_log(fn ->
        pipeline.id |> pipeline_event() |> CacheInvalidator.pipeline_event()
      end)

      assert refreshed_ref_types(project) == []
      assert cached_ref_types(project) == @ref_types
    end
  end

  describe "pipeline_summary_event" do
    test "invalidates only the list of all git refs when the pipeline has no hook yet", %{
      project: project
    } do
      pipeline = pipeline_without_hook()

      put_all_cache_keys(project)

      InternalApi.Velocity.PipelineSummaryAvailableEvent.new(
        pipeline_id: pipeline.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Velocity.PipelineSummaryAvailableEvent.encode()
      |> CacheInvalidator.pipeline_summary_event()

      assert cached_ref_types(project) == ["branch", "pr", "tag"]
    end
  end

  describe "project_updated" do
    test "invalidates project page caches", %{organization: organization, project: project} do
      tag_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=tag/list_mode=latest/"

      branch_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=branch/list_mode=latest/"

      pr_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=pr/list_mode=latest/"

      all_git_refs_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=/list_mode=latest/"

      Cacheman.put(
        :front,
        tag_cache_key,
        "test content"
      )

      Cacheman.put(
        :front,
        branch_cache_key,
        "test content"
      )

      Cacheman.put(
        :front,
        pr_cache_key,
        "test content"
      )

      Cacheman.put(
        :front,
        all_git_refs_cache_key,
        "test content"
      )

      InternalApi.Projecthub.ProjectUpdated.new(
        project_id: project.id,
        org_id: organization.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Projecthub.ProjectUpdated.encode()
      |> CacheInvalidator.project_updated()

      refute Cacheman.exists?(:front, tag_cache_key)
      refute Cacheman.exists?(:front, branch_cache_key)
      refute Cacheman.exists?(:front, pr_cache_key)
      refute Cacheman.exists?(:front, all_git_refs_cache_key)
    end
  end

  defp pipeline_event(pipeline_id) do
    InternalApi.Plumber.PipelineEvent.new(
      pipeline_id: pipeline_id,
      timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
    )
    |> InternalApi.Plumber.PipelineEvent.encode()
  end

  defp pipeline_with_hook(hook_params) do
    hook = Stubs.Hook.create(DB.first(:branches), hook_params)
    workflow = Stubs.Workflow.create(hook, DB.first(:users))

    Stubs.Pipeline.create_initial(workflow)
  end

  # Pipelines started by the API or a task carry no hook or branch until the hook exists.
  defp pipeline_without_hook do
    DB.first(:workflows) |> Stubs.Pipeline.create(hook_id: "", branch_id: "")
  end

  defp pipeline_with_unknown_hook do
    DB.first(:workflows) |> Stubs.Pipeline.create(hook_id: Ecto.UUID.generate())
  end

  defp pipeline_with_unknown_project do
    DB.first(:workflows) |> Stubs.Pipeline.create(project_id: Ecto.UUID.generate())
  end

  defp cache_key(project, ref_type) do
    "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=#{ref_type}/list_mode=latest/"
  end

  defp put_all_cache_keys(project) do
    Enum.each(@ref_types, fn ref_type ->
      Cacheman.put(:front, cache_key(project, ref_type), "test content")
    end)
  end

  defp cached_ref_types(project) do
    Enum.filter(@ref_types, &Cacheman.exists?(:front, cache_key(project, &1)))
  end

  defp refreshed_ref_types(project) do
    Enum.filter(@ref_types, fn ref_type ->
      case Cacheman.get(:front, cache_key(project, ref_type)) do
        {:ok, "test content"} -> false
        {:ok, nil} -> false
        {:ok, encoded} -> match?(%Model{}, Model.decode(encoded))
      end
    end)
  end
end
