defmodule Front.DashboardPage.CacheInvalidatorTest do
  use ExUnit.Case

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
