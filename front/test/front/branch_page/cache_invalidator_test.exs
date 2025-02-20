defmodule Front.BranchPage.CacheInvalidatorTest do
  use ExUnit.Case

  alias Support.Stubs.DB

  alias Front.BranchPage.CacheInvalidator
  alias Front.BranchPage.Model

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    branch = DB.first(:branches)
    pipeline = DB.first(:pipelines)

    [
      branch: branch,
      pipeline: pipeline
    ]
  end

  describe "pipeline_event" do
    test "invalidates project page caches for one git ref and all together", %{
      branch: branch,
      pipeline: pipeline
    } do
      cache_key = "branch_page_model/#{Model.cache_version()}/branch_id=#{branch.id}/"

      Cacheman.put(
        :front,
        cache_key,
        "test content"
      )

      assert Cacheman.exists?(:front, cache_key)

      InternalApi.Plumber.PipelineEvent.new(
        pipeline_id: pipeline.id,
        timestamp: %Google.Protobuf.Timestamp{seconds: 1, nanos: 1}
      )
      |> InternalApi.Plumber.PipelineEvent.encode()
      |> CacheInvalidator.pipeline_event()

      refute Cacheman.exists?(:front, cache_key)
    end
  end
end
