defmodule Ppl.Ppls.Model.TriggererTest do
  use ExUnit.Case, async: true
  alias Ppl.Ppls.Model.Triggerer

  describe "#to_grpc" do
    test "when it's an initial pipeline of workflow" do
      requester_data = %{
        initial_request: true,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "hook",
        auto_promoted: false,
        promoter_id: "",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "",
        partial_rerun_of: "",
        promotion_of: "",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
        wf_triggerer_id: "hook_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:WORKFLOW),
        ppl_triggerer_id: "workflow_id",
        ppl_triggerer_user_id: "requester_id",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when it's a rerun of a workflow" do
      requester_data = %{
        initial_request: true,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "hook",
        auto_promoted: false,
        promoter_id: "",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "",
        partial_rerun_of: "",
        promotion_of: "",
        wf_rebuild_of: "wf_rebuild_of",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
        wf_triggerer_id: "hook_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:WORKFLOW),
        ppl_triggerer_id: "workflow_id",
        ppl_triggerer_user_id: "requester_id",
        workflow_rerun_of: "wf_rebuild_of"
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when pipeline was scheduled by the wf API call" do
      requester_data = %{
        initial_request: true,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "api",
        auto_promoted: false,
        promoter_id: "",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "",
        partial_rerun_of: "",
        promotion_of: "",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:API),
        wf_triggerer_id: "",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:WORKFLOW),
        ppl_triggerer_id: "workflow_id",
        ppl_triggerer_user_id: "requester_id",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when pipeline is triggered by scheduled run of the task" do
      requester_data = %{
        initial_request: true,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "schedule",
        auto_promoted: false,
        promoter_id: "",
        requester_id: "requester_id",
        scheduler_task_id: "scheduler_task_id",
        partially_rerun_by: "",
        partial_rerun_of: "",
        promotion_of: "",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:SCHEDULE),
        wf_triggerer_id: "scheduler_task_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:WORKFLOW),
        ppl_triggerer_id: "workflow_id",
        ppl_triggerer_user_id: "requester_id",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when pipeline is triggered by a manual run of a task" do
      requester_data = %{
        initial_request: true,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "manual_run",
        auto_promoted: false,
        promoter_id: "",
        requester_id: "requester_id",
        scheduler_task_id: "scheduler_task_id",
        partially_rerun_by: "",
        partial_rerun_of: "",
        promotion_of: "",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:MANUAL_RUN),
        wf_triggerer_id: "scheduler_task_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:WORKFLOW),
        ppl_triggerer_id: "workflow_id",
        ppl_triggerer_user_id: "requester_id",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when pipeline is triggered by a manual promotion" do
      requester_data = %{
        initial_request: false,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "hook",
        auto_promoted: false,
        promoter_id: "promoter_id",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "",
        partial_rerun_of: "",
        promotion_of: "promotion_of",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
        wf_triggerer_id: "hook_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:PROMOTION),
        ppl_triggerer_id: "promotion_of",
        ppl_triggerer_user_id: "promoter_id",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when pipeline is triggered by an auto promotion" do
      requester_data = %{
        initial_request: false,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "hook",
        auto_promoted: true,
        promoter_id: "",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "",
        partial_rerun_of: "",
        promotion_of: "promotion_of",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
        wf_triggerer_id: "hook_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:AUTO_PROMOTION),
        ppl_triggerer_id: "promotion_of",
        ppl_triggerer_user_id: "",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when pipeline is triggered by a partial rerun of the pipeline" do
      requester_data = %{
        initial_request: false,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "hook",
        auto_promoted: false,
        promoter_id: "",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "partially_rerun_by",
        partial_rerun_of: "partial_rerun_of",
        promotion_of: "",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
        wf_triggerer_id: "hook_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:PARTIAL_RE_RUN),
        ppl_triggerer_id: "partial_rerun_of",
        ppl_triggerer_user_id: "partially_rerun_by",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

    test "when pipeline is triggered by a partial rerun of a promoted pipeline" do
      requester_data = %{
        initial_request: false,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "hook",
        auto_promoted: false,
        promoter_id: "promoter_id",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "partially_rerun_by",
        partial_rerun_of: "partial_rerun_of",
        promotion_of: "promotion_of",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
        wf_triggerer_id: "hook_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:PARTIAL_RE_RUN),
        ppl_triggerer_id: "partial_rerun_of",
        ppl_triggerer_user_id: "partially_rerun_by",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end

        test "when pipeline is triggered by a partial rerun of an auto-promoted pipeline" do
      requester_data = %{
        initial_request: false,
        hook_id: "hook_id",
        provider_uid: "123",
        provider_author: "author",
        provider_avatar: "avatar",
        triggered_by: "hook",
        auto_promoted: true,
        promoter_id: "promoter_id",
        requester_id: "requester_id",
        scheduler_task_id: "",
        partially_rerun_by: "partially_rerun_by",
        partial_rerun_of: "partial_rerun_of",
        promotion_of: "promotion_of",
        wf_rebuild_of: "",
        workflow_id: "workflow_id",
      }

      expected = %{
        wf_triggerer_provider_login: "author",
        wf_triggerer_provider_uid: "123",
        wf_triggerer_provider_avatar: "avatar",
        wf_triggered_by: InternalApi.PlumberWF.TriggeredBy.value(:HOOK),
        wf_triggerer_id: "hook_id",
        wf_triggerer_user_id: "requester_id",
        ppl_triggered_by: InternalApi.Plumber.TriggeredBy.value(:PARTIAL_RE_RUN),
        ppl_triggerer_id: "partial_rerun_of",
        ppl_triggerer_user_id: "partially_rerun_by",
        workflow_rerun_of: ""
      }

      assert Triggerer.to_grpc(requester_data) == expected
    end
  end
end
