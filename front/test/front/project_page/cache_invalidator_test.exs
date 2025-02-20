defmodule Front.ProjectPage.CacheInvalidatorTest do
  use ExUnit.Case

  alias Support.Stubs.DB

  alias Front.ProjectPage.CacheInvalidator
  alias Front.ProjectPage.Model

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
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=branch/"

      all_git_refs_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=/"

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
  end

  describe "project_updated" do
    test "invalidates project page caches", %{organization: organization, project: project} do
      tag_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=tag/"

      branch_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=branch/"

      pr_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=pr/"

      all_git_refs_cache_key =
        "project_page_model/#{Model.cache_version()}/project_id=#{project.id}/ref_types=/"

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
end
