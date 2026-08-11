defmodule Front.DashboardPage.CacheInvalidatorTest do
  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Front.DashboardPage.CacheInvalidator
  alias Front.DashboardPage.Model
  alias Front.DashboardPage.Model.LoadParams
  alias Support.Stubs.DB

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)
    project = DB.first(:projects)
    pipeline = DB.first(:pipelines)

    params =
      struct!(LoadParams,
        organization_id: organization.id,
        user_id: user.id,
        requester: false
      )

    [
      params: params,
      project: project,
      pipeline: pipeline
    ]
  end

  describe "pipeline_event" do
    test "invalidates dashboard page cache for organization", %{
      params: params,
      pipeline: pipeline
    } do
      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)

      assert Cacheman.exists?(:front, Model.cache_key(params))

      InternalApi.Plumber.PipelineEvent.new(
        pipeline_id: pipeline.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Plumber.PipelineEvent.encode()
      |> CacheInvalidator.pipeline_event()

      refute Cacheman.exists?(:front, Model.cache_key(params))
    end

    test "does not crash when pipeline metadata is missing" do
      unknown_pipeline_id = Ecto.UUID.generate()

      event =
        InternalApi.Plumber.PipelineEvent.new(
          pipeline_id: unknown_pipeline_id,
          timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
        )
        |> InternalApi.Plumber.PipelineEvent.encode()

      log =
        capture_log(fn ->
          CacheInvalidator.pipeline_event(event)
        end)

      assert log =~ "PIPELINE INVALIDATION"
      assert log =~ unknown_pipeline_id
    end

    test "still invalidates cache when event has nil timestamp", %{
      params: params,
      pipeline: pipeline
    } do
      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)
      assert Cacheman.exists?(:front, Model.cache_key(params))

      InternalApi.Plumber.PipelineEvent.new(pipeline_id: pipeline.id)
      |> InternalApi.Plumber.PipelineEvent.encode()
      |> CacheInvalidator.pipeline_event()

      refute Cacheman.exists?(:front, Model.cache_key(params))
    end
  end

  describe "pipeline_summary_event" do
    test "invalidates dashboard page cache for organization", %{
      params: params,
      pipeline: pipeline
    } do
      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)

      assert Cacheman.exists?(:front, Model.cache_key(params))

      InternalApi.Velocity.PipelineSummaryAvailableEvent.new(
        pipeline_id: pipeline.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Velocity.PipelineSummaryAvailableEvent.encode()
      |> CacheInvalidator.pipeline_summary_event()

      refute Cacheman.exists?(:front, Model.cache_key(params))
    end

    test "does not crash when pipeline metadata is missing" do
      unknown_pipeline_id = Ecto.UUID.generate()

      event =
        InternalApi.Velocity.PipelineSummaryAvailableEvent.new(
          pipeline_id: unknown_pipeline_id,
          timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
        )
        |> InternalApi.Velocity.PipelineSummaryAvailableEvent.encode()

      log =
        capture_log(fn ->
          CacheInvalidator.pipeline_summary_event(event)
        end)

      assert log =~ "PIPELINE INVALIDATION"
      assert log =~ unknown_pipeline_id
    end

    test "still invalidates cache when event has nil timestamp", %{
      params: params,
      pipeline: pipeline
    } do
      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)
      assert Cacheman.exists?(:front, Model.cache_key(params))

      InternalApi.Velocity.PipelineSummaryAvailableEvent.new(pipeline_id: pipeline.id)
      |> InternalApi.Velocity.PipelineSummaryAvailableEvent.encode()
      |> CacheInvalidator.pipeline_summary_event()

      refute Cacheman.exists?(:front, Model.cache_key(params))
    end
  end

  describe "pipeline_event with project lookup unavailable" do
    test "still invalidates cache using organization_id from pipeline metadata", %{
      params: params,
      pipeline: pipeline
    } do
      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)
      assert Cacheman.exists?(:front, Model.cache_key(params))

      # Even if Models.Project.find_by_id were to fail, invalidation should
      # succeed because we read organization_id directly from pipeline metadata.
      InternalApi.Plumber.PipelineEvent.new(
        pipeline_id: pipeline.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Plumber.PipelineEvent.encode()
      |> CacheInvalidator.pipeline_event()

      refute Cacheman.exists?(:front, Model.cache_key(params))
    end
  end

  describe "project_updated" do
    test "invalidates dashboard page cache for organization", %{params: params, project: project} do
      {:ok, _payload, :from_api} = Model.get(params, fn -> {:ok, [:workflow], "", ""} end)

      assert Cacheman.exists?(:front, Model.cache_key(params))

      InternalApi.Projecthub.ProjectUpdated.new(
        project_id: project.id,
        org_id: project.org_id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Projecthub.ProjectUpdated.encode()
      |> CacheInvalidator.project_updated()

      refute Cacheman.exists?(:front, Model.cache_key(params))
    end
  end
end
