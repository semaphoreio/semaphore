# credo:disable-for-this-file Credo.Check.Readability.LargeNumbers

defmodule Front.Models.PipelineTest do
  use Front.TestCase

  alias Front.Models
  alias InternalApi.Plumber.DescribeTopologyResponse
  alias InternalApi.Plumber.ResponseStatus
  alias Support.Stubs

  alias Support.Stubs.DB

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    user = DB.first(:users)
    organization = DB.first(:organizations)
    pipeline = DB.first(:pipelines)
    workflow = DB.first(:workflows)

    [
      user: user,
      organization: organization,
      pipeline: pipeline,
      workflow: workflow
    ]
  end

  describe ".find_metadata" do
    test "returns pipeline metadata from the cache when exists", %{
      pipeline: pipeline,
      organization: organization
    } do
      ppl = %{
        id: pipeline.id,
        organization_id: organization.id,
        workflow_id: "1",
        project_id: "2",
        branch_id: "3",
        hook_id: "4",
        switch_id: "5"
      }

      Cacheman.put(:front, Models.Pipeline.cache_key(pipeline.id), :erlang.term_to_binary(ppl))

      assert Models.Pipeline.find_metadata(pipeline.id) == ppl
    end

    test "returns pipeline metadata from the API and puts it in the cache when the cache is empty",
         %{pipeline: pipeline, organization: organization} do
      refute Cacheman.exists?(:front, pipeline.id)

      assert Models.Pipeline.find_metadata(pipeline.id) ==
               %{
                 organization_id: organization.id,
                 branch_id: pipeline.api_model.branch_id,
                 hook_id: pipeline.api_model.hook_id,
                 id: pipeline.id,
                 project_id: pipeline.api_model.project_id,
                 switch_id: pipeline.api_model.switch_id,
                 workflow_id: pipeline.api_model.wf_id
               }

      assert Cacheman.exists?(:front, Models.Pipeline.cache_key(pipeline.id))
    end
  end

  describe ".path" do
    test "returns pipeline", %{pipeline: pipeline} do
      assert Models.Pipeline.path(pipeline.id).__struct__ ==
               Models.Pipeline
    end

    test "returns recursive chain of pipelines and switches", %{pipeline: pipeline} do
      root_pipeline = Models.Pipeline.path(pipeline.id)

      assert root_pipeline
      assert root_pipeline.switch
      refute root_pipeline.switch.pipeline
    end

    test "when folding skipped blocks is enabled then blocks have indirect dependencies",
         %{pipeline: pipeline} do
      root_pipeline = Models.Pipeline.path(pipeline.id, fold_skipped_blocks?: true)

      assert root_pipeline
      assert root_pipeline.switch

      assert Enum.all?(root_pipeline.blocks, &Map.has_key?(&1, :indirect_dependencies))
    end

    test "when folding skipped blocks is disabled then blocks have indirect dependencies",
         %{pipeline: pipeline} do
      root_pipeline = Models.Pipeline.path(pipeline.id)

      assert root_pipeline
      assert root_pipeline.switch

      refute Enum.any?(root_pipeline.blocks, &Map.has_key?(&1, :indirect_dependencies))
    end
  end

  describe ".preload_terminators" do
    test "fetches the terminators for stopped pipelines", %{user: user} do
      pipelines = [
        %{
          terminated_by: user.id
        },
        %{
          terminated_by: ""
        }
      ]

      assert Models.Pipeline.preload_terminators(pipelines, nil) == [
               %{
                 terminated_by: user.id,
                 terminator: Models.User.find(user.id)
               },
               %{
                 terminated_by: ""
               }
             ]
    end

    test "when the pipeline is not user terminated => doesn't try to find the terminator" do
      pipelines = [
        %{
          terminated_by: "branch deletion"
        }
      ]

      pipes = Models.Pipeline.preload_terminators(pipelines, nil)

      assert pipes == [
               %{
                 terminated_by: "branch deletion"
               }
             ]
    end
  end

  describe ".list" do
    test "when response is BAD => returns []" do
      response =
        InternalApi.Plumber.ListResponse.new(
          response_status:
            InternalApi.Plumber.ResponseStatus.new(
              code: InternalApi.Plumber.ResponseStatus.ResponseCode.value(:BAD_PARAM)
            ),
          pipelines: []
        )

      GrpcMock.stub(PipelineMock, :list, response)

      assert Models.Pipeline.list() == nil
    end
  end

  describe ".find" do
    test "when pipeline_id is empty return nil" do
      assert Models.Pipeline.find("") == nil
      assert Models.Pipeline.find(nil) == nil
    end

    test "when the response is successfull => returns a pipeline", %{pipeline: pipeline} do
      ppl = Models.Pipeline.find(pipeline.id)

      assert ppl.id == pipeline.id
    end
  end

  describe ".topology" do
    test "returns pipeline topology and caches it", %{pipeline: pipeline} do
      refute Cacheman.exists?(
               :front,
               "pipeline-model-topology/#{Models.Pipeline.topology_cache_version()}/#{pipeline.id}"
             )

      assert Models.Pipeline.topology(pipeline.id) == %Models.Pipeline{
               blocks: [
                 %{
                   name: "Block 1",
                   jobs: [%{name: "job 1"}, %{name: "job 2"}, %{name: "job 3"}],
                   dependencies: [],
                   build_request_id: nil,
                   skipped?: false,
                   result: nil,
                   state: nil,
                   id: nil
                 }
               ],
               after_task: %Models.Pipeline.AfterTask{jobs: [], task_id: nil, present?: false}
             }

      assert Cacheman.exists?(
               :front,
               "pipeline-model-topology/#{Models.Pipeline.topology_cache_version()}/#{pipeline.id}"
             )
    end

    test "doesn't cache the topology if its empty", %{pipeline: pipeline} do
      refute Cacheman.exists?(
               :front,
               "pipeline-model-topology/#{Models.Pipeline.topology_cache_version()}/#{pipeline.id}"
             )

      response = %DescribeTopologyResponse{
        blocks: [],
        after_pipeline: %DescribeTopologyResponse.AfterPipeline{jobs: []},
        status: %ResponseStatus{code: 0, message: ""}
      }

      GrpcMock.stub(PipelineMock, :describe_topology, response)

      assert Models.Pipeline.topology(pipeline.id) == %Models.Pipeline{
               blocks: [],
               after_task: %Models.Pipeline.AfterTask{jobs: [], task_id: nil, present?: false}
             }

      refute Cacheman.exists?(
               :front,
               "pipeline-model-topology/#{Models.Pipeline.topology_cache_version()}/#{pipeline.id}"
             )
    end
  end

  describe ".find_many" do
    test "returns pipelines", %{pipeline: pipeline} do
      response_list = Models.Pipeline.find_many([pipeline.id])

      assert Enum.count(response_list) == 1
    end
  end

  describe ".preload_origins" do
    test "assigns origin for promoted pipelines", %{pipeline: pipeline, workflow: workflow} do
      switch = Stubs.Pipeline.add_switch(pipeline)

      promoted_pipelines = [
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id),
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id),
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id)
      ]

      target = Stubs.Switch.add_target(switch)

      promoted_pipelines
      |> Enum.each(fn p ->
        Stubs.Switch.add_trigger_event(target,
          scheduled_pipeline_id: p.api_model.ppl_id,
          auto_triggered: false
        )
      end)

      ids = promoted_pipelines |> Enum.map(fn p -> p.id end)

      pipelines_with_promoter =
        Models.Pipeline.find_many(ids) |> Models.Pipeline.preload_origins("")

      pipelines_with_promoter
      |> Enum.each(fn p ->
        assert p.origin.id == pipeline.id
      end)
    end

    test "assigns promoted_by for manually promoted pipelines", %{
      pipeline: pipeline,
      workflow: workflow,
      user: user
    } do
      switch = Stubs.Pipeline.add_switch(pipeline)

      promoted_pipelines = [
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id),
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id),
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id)
      ]

      target = Stubs.Switch.add_target(switch)

      promoted_pipelines
      |> Enum.each(fn p ->
        Stubs.Switch.add_trigger_event(target,
          scheduled_pipeline_id: p.api_model.ppl_id,
          auto_triggered: false,
          triggered_by: user.id
        )
      end)

      ids = promoted_pipelines |> Enum.map(fn p -> p.id end)

      pipelines_with_promoter =
        Models.Pipeline.find_many(ids) |> Models.Pipeline.preload_origins("")

      pipelines_with_promoter
      |> Enum.each(fn p ->
        assert p.promoted_by
      end)
    end

    test "doesn't assign promoted_by for auto promoted pipelines", %{
      pipeline: pipeline,
      workflow: workflow
    } do
      switch = Stubs.Pipeline.add_switch(pipeline)

      promoted_pipelines = [
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id),
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id),
        Stubs.Pipeline.create(workflow, promotion_of: pipeline.id)
      ]

      target = Stubs.Switch.add_target(switch)

      promoted_pipelines
      |> Enum.each(fn p ->
        Stubs.Switch.add_trigger_event(target,
          scheduled_pipeline_id: p.api_model.ppl_id,
          auto_triggered: true
        )
      end)

      ids = promoted_pipelines |> Enum.map(fn p -> p.id end)

      pipelines_with_promoter =
        Models.Pipeline.find_many(ids) |> Models.Pipeline.preload_origins("")

      pipelines_with_promoter
      |> Enum.each(fn pipeline ->
        refute Map.has_key?(pipeline, :promoted_by)
      end)
    end

    test "assigns origin for rebuilt promotions", %{
      pipeline: pipeline,
      workflow: workflow,
      user: user
    } do
      switch = Stubs.Pipeline.add_switch(pipeline)

      promoted_pipeline = Stubs.Pipeline.create(workflow, promotion_of: pipeline.id)

      rebuilt_pipelines = [
        Stubs.Pipeline.create(workflow,
          promotion_of: pipeline.id,
          partially_rerun_by: promoted_pipeline.id
        ),
        Stubs.Pipeline.create(workflow,
          promotion_of: pipeline.id,
          partially_rerun_by: promoted_pipeline.id
        )
      ]

      target = Stubs.Switch.add_target(switch)

      Stubs.Switch.add_trigger_event(target,
        scheduled_pipeline_id: promoted_pipeline.api_model.ppl_id,
        auto_triggered: false,
        triggered_by: user.id
      )

      ids = rebuilt_pipelines |> Enum.map(fn p -> p.id end)

      rebuilt_pipelines = Models.Pipeline.find_many(ids) |> Models.Pipeline.preload_origins("")

      rebuilt_pipelines
      |> Enum.each(fn p ->
        assert p.origin.id == pipeline.id
      end)
    end

    test "doesn't assign promoted_by for rebuilt promotions", %{
      workflow: workflow,
      pipeline: pipeline
    } do
      switch = Stubs.Pipeline.add_switch(pipeline)

      promoted_pipeline = Stubs.Pipeline.create(workflow, promotion_of: pipeline.id)

      rebuilt_pipelines = [
        Stubs.Pipeline.create(workflow,
          promotion_of: pipeline.id,
          partially_rerun_by: promoted_pipeline.id
        ),
        Stubs.Pipeline.create(workflow,
          promotion_of: pipeline.id,
          partially_rerun_by: promoted_pipeline.id
        )
      ]

      target = Stubs.Switch.add_target(switch)

      Stubs.Switch.add_trigger_event(target,
        scheduled_pipeline_id: promoted_pipeline.api_model.ppl_id,
        auto_triggered: false
      )

      ids = rebuilt_pipelines |> Enum.map(fn p -> p.id end)

      rebuilt_pipelines = Models.Pipeline.find_many(ids) |> Models.Pipeline.preload_origins("")

      rebuilt_pipelines
      |> Enum.each(fn p ->
        refute Map.has_key?(p, :promoted_by)
      end)
    end
  end
end
