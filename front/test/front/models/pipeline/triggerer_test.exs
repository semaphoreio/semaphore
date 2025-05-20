defmodule Front.Models.Pipeline.TriggererTest do
  use ExUnit.Case
  alias Front.Models.Pipeline.Triggerer
  alias InternalApi.Plumber.Pipeline.Result, as: PplResult
  alias Support.Factories

  describe "#construct for initial ppl" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:INITIAL_WORKFLOW)
      triggerer = Triggerer.construct(pipeline)

      assert :INITIAL_WORKFLOW == triggerer.trigger_type
      assert {:hook, _} = triggerer.triggered_by
      assert {:name, _} = triggerer.owner
    end
  end

  describe "#construct for api run" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:API)
      triggerer = Triggerer.construct(pipeline)

      assert :API == triggerer.trigger_type
      assert :none == triggerer.triggered_by
      assert {:user, _} = triggerer.owner
    end
  end

  describe "#construct for scheduled run" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:SCHEDULED_RUN)
      triggerer = Triggerer.construct(pipeline)

      assert :SCHEDULED_RUN == triggerer.trigger_type
      assert {:task, _} = triggerer.triggered_by
      assert :none == triggerer.owner
    end

    test "constructs proper triggerer for promotions" do
      pipeline = Factories.pipeline_with_trigger(:SCHEDULED_RUN_WITH_PROMOTION)
      triggerer = Triggerer.construct(pipeline)

      assert :MANUAL_PROMOTION == triggerer.trigger_type
      assert :none = triggerer.triggered_by
      assert {:user, _} = triggerer.owner
    end
  end

  describe "#construct for scheduled manual run" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:SCHEDULED_MANUAL_RUN)
      triggerer = Triggerer.construct(pipeline)

      assert :SCHEDULED_MANUAL_RUN == triggerer.trigger_type
      assert {:task, _} = triggerer.triggered_by
      assert {:user, _} = triggerer.owner
    end
  end

  describe "#construct for partial rerun" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:PIPELINE_PARTIAL_RERUN)
      triggerer = Triggerer.construct(pipeline)

      assert :PIPELINE_PARTIAL_RERUN == triggerer.trigger_type
      assert {:pipeline, _} = triggerer.triggered_by
      assert {:user, _} = triggerer.owner
    end
  end

  describe "#construct for manual promotion" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:MANUAL_PROMOTION)
      triggerer = Triggerer.construct(pipeline)

      assert :MANUAL_PROMOTION == triggerer.trigger_type
      assert :none == triggerer.triggered_by
      assert {:user, _} = triggerer.owner
    end
  end

  describe "#construct for auto promotion" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:AUTO_PROMOTION)
      triggerer = Triggerer.construct(pipeline)

      assert :AUTO_PROMOTION == triggerer.trigger_type
      assert :none == triggerer.triggered_by
      assert :none == triggerer.owner
    end
  end

  describe "#construct for a workflow rerun" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline_with_trigger(:WORKFLOW_RERUN)
      triggerer = Triggerer.construct(pipeline)

      assert :WORKFLOW_RERUN == triggerer.trigger_type
      assert {:workflow, _} = triggerer.triggered_by
      assert {:user, _} = triggerer.owner
    end
  end

  describe "#construct for terminated ppls" do
    test "constructs proper triggerer" do
      pipeline = Factories.pipeline()
      triggerer = Triggerer.construct(pipeline)
      assert false == triggerer.is_terminated?
      assert :none == triggerer.terminated_by

      triggerer = Triggerer.construct(%{pipeline | terminated_by: "admin"})
      assert true == triggerer.is_terminated?
      assert {:name, "admin"} == triggerer.terminated_by

      triggerer = Triggerer.construct(%{pipeline | terminated_by: "branch deletion"})
      assert true == triggerer.is_terminated?
      assert {:name, "branch deletion"} == triggerer.terminated_by

      triggerer = Triggerer.construct(%{pipeline | terminated_by: Ecto.UUID.generate()})
      assert true == triggerer.is_terminated?
      assert {:user, {_, _}} = triggerer.terminated_by

      triggerer = Triggerer.construct(%{pipeline | result: PplResult.value(:STOPPED)})
      assert true == triggerer.is_terminated?
      assert :none == triggerer.terminated_by

      triggerer = Triggerer.construct(%{pipeline | result: PplResult.value(:CANCELED)})
      assert true == triggerer.is_terminated?
      assert :none == triggerer.terminated_by

      triggerer = Triggerer.construct(%{pipeline | terminated_by: "voodoo"})
      assert true == triggerer.is_terminated?
      assert :none == triggerer.terminated_by
    end
  end

  describe "#construct" do
    test "properly assumes git user" do
      pipeline =
        Factories.pipeline(
          triggerer: [
            wf_triggerer_provider_login: "foo_login",
            wf_triggerer_provider_avatar: "foo_avatar"
          ]
        )

      triggerer = Triggerer.construct(pipeline)
      assert "foo_login" == triggerer.git_user
      assert "foo_avatar" == triggerer.git_avatar_url

      pipeline =
        Factories.pipeline(
          triggerer: [
            wf_triggerer_provider_login: "bar_login",
            wf_triggerer_provider_avatar: "bar_avatar"
          ]
        )

      triggerer = Triggerer.construct(pipeline)
      assert "bar_login" == triggerer.git_user
      assert "bar_avatar" == triggerer.git_avatar_url
    end
  end

  describe "#users_to_preload" do
    test "returns only user entities that needs preloading" do
      triggerer = %Triggerer{
        owner: {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", ""}},
        terminated_by: {:user, {"56e4aaf6-bc00-46f2-b341-900e73a7b01f", "barsky"}}
      }

      users = Triggerer.users_to_preload(triggerer)
      assert 1 == length(users)
      assert {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", ""}} in users
    end
  end

  describe "#preload_users" do
    test "preloads user names" do
      triggerer = %Triggerer{
        owner: {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", ""}},
        terminated_by: {:user, {"56e4aaf6-bc00-46f2-b341-900e73a7b01f", ""}}
      }

      triggerer =
        Triggerer.preload_users(triggerer, [
          {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", "foo"}},
          {:user, {"56e4aaf6-bc00-46f2-b341-900e73a7b01f", "barsky"}}
        ])

      assert {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", "foo"}} ==
               triggerer.owner

      assert {:user, {"56e4aaf6-bc00-46f2-b341-900e73a7b01f", "barsky"}} ==
               triggerer.terminated_by
    end

    test "preloads user names only for users that does not have a name" do
      triggerer = %Triggerer{
        owner: {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", ""}},
        terminated_by: {:user, {"56e4aaf6-bc00-46f2-b341-900e73a7b01f", "barsky"}}
      }

      triggerer =
        Triggerer.preload_users(triggerer, [
          {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", "foo"}}
        ])

      assert {:user, {"eedea26b-1bcf-43f5-9e52-55566e051371", "foo"}} ==
               triggerer.owner

      assert {:user, {"56e4aaf6-bc00-46f2-b341-900e73a7b01f", "barsky"}} ==
               triggerer.terminated_by
    end
  end
end
