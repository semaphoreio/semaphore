defmodule Front.Models.SwitchTest do
  use FrontWeb.ConnCase

  alias Front.Models
  alias InternalApi.Plumber
  alias Support.Factories
  alias Support.Stubs.DB

  setup do
    Cacheman.clear(:front)

    Support.Stubs.init()
    Support.Stubs.build_shared_factories()

    switch = DB.first(:switches)
    user = DB.first(:users)

    [
      switch: switch,
      user: user
    ]
  end

  describe ".find" do
    test "when found => returns constructed models", %{switch: switch} do
      s = Models.Switch.find(switch.id, "")

      assert s.id === switch.id
    end

    test "when has deployment targets => returns contructed models", %{switch: switch} do
      dt_desc1 = %{
        target_id: "123456",
        target_name: "prod1",
        access: %{
          allowed: false,
          reason: :BANNED_OBJECT,
          message: "You shall not pass"
        }
      }

      dt_desc2 = %{
        target_id: "abcdef",
        target_name: "prod2",
        access: %{
          allowed: true,
          reason: :NO_REASON,
          message: ""
        }
      }

      t1 = Support.Stubs.Switch.add_target(switch, name: "T1", dt_description: dt_desc1)
      t2 = Support.Stubs.Switch.add_target(switch, name: "T2", dt_description: dt_desc2)

      assert switch = Models.Switch.find(switch.id, UUID.uuid4())

      assert target = Enum.find(switch.targets, &(&1.name == "T1"))
      assert target.deployment.name == "prod1"
      refute target.deployment.allowed?
      assert target.deployment.reason == :BANNED_OBJECT
      assert target.deployment.message == "You shall not pass"

      assert target = Enum.find(switch.targets, &(&1.name == "T2"))
      assert target.deployment.name == "prod2"
      assert target.deployment.allowed?
      assert target.deployment.reason == :NO_REASON
      assert target.deployment.message == ""

      Support.Stubs.Switch.remove_target(t1)
      Support.Stubs.Switch.remove_target(t2)
    end

    test "when not found => returns nil" do
      assert Models.Switch.find("c6e4c82e-df20-4bed-b700-f385720af9e2", "") == nil
    end
  end

  describe ".find_target_by_name" do
    test "when the target is found => it returns the target", %{switch: switch} do
      s = Models.Switch.find(switch.id, "")

      assert Models.Switch.find_target_by_name(s, "staging") == Enum.at(s.targets, 1)
    end

    test "when the target is not found => it returns nil", %{switch: switch} do
      s = Models.Switch.find(switch.id, "")

      assert Models.Switch.find_target_by_name(s, "staging2") == nil
    end
  end

  describe "Target.trigger" do
    test "if triggering succeds => returns {:ok, nil}", %{switch: switch, user: user} do
      s = Models.Switch.find(switch.id, "")
      t1 = Enum.at(s.targets, 0)

      refute t1.deployment
      assert Models.Switch.Target.trigger(t1, user.id) == {:ok, nil}
    end

    test "if triggering fails => returns {:error, msg}", %{switch: switch, user: user} do
      GrpcMock.stub(GoferMock, :trigger, Factories.Gofer.failed_trigger_response())

      s = Models.Switch.find(switch.id, "")
      t1 = Enum.at(s.targets, 0)

      refute t1.deployment

      assert Models.Switch.Target.trigger(t1, user.id) ==
               {:error, :BAD_PARAM, "Promotion request is invalid."}
    end

    test "if triggering is refused => returns error code and message", %{
      switch: switch,
      user: user
    } do
      GrpcMock.stub(GoferMock, :trigger, Factories.Gofer.refused_trigger_response("Rate limited"))

      s = Models.Switch.find(switch.id, "")
      t1 = Enum.at(s.targets, 0)

      refute t1.deployment
      assert Models.Switch.Target.trigger(t1, user.id) == {:error, :REFUSED, "Rate limited"}
    end

    test "if deployment target allows => returns {:ok, nil}", %{switch: switch, user: user} do
      dt_access = %{allowed: true, reason: :NO_REASON, message: "allowed target"}
      dt_description = %{target_id: "dt_id", target_name: "dt_name", access: dt_access}

      :targets
      |> DB.find_all_by(:switch_id, switch.id)
      |> Enum.map(&Map.put(&1, :dt_description, dt_description))
      |> Enum.each(&DB.upsert(:targets, &1))

      s = Models.Switch.find(switch.id, "")
      t1 = Enum.at(s.targets, 0)

      assert Models.Switch.Target.trigger(t1, user.id) ==
               {:ok, nil}
    end

    test "if deployment target denies => returns {:error, msg}", %{switch: switch, user: user} do
      dt_access = %{allowed: false, reason: :SYNCING_TARGET, message: "syncing target"}
      dt_description = %{target_id: "dt_id", target_name: "dt_name", access: dt_access}

      :targets
      |> DB.find_all_by(:switch_id, switch.id)
      |> Enum.map(&Map.put(&1, :dt_description, dt_description))
      |> Enum.each(&DB.upsert(:targets, &1))

      s = Models.Switch.find(switch.id, "")
      t1 = Enum.at(s.targets, 0)

      assert Models.Switch.Target.trigger(t1, user.id) ==
               {:error, :REFUSED, "Triggering promotion blocked by deployment target"}
    end
  end

  describe "TriggerEvent.construct" do
    test "maps error_response on failed trigger events" do
      raw =
        InternalApi.Gofer.TriggerEvent.new(
          processing_result: InternalApi.Gofer.TriggerEvent.ProcessingResult.value(:FAILED),
          triggered_by: "user-1",
          triggered_at: Google.Protobuf.Timestamp.new(seconds: 1),
          scheduled_pipeline_id: "",
          processed: true,
          auto_triggered: false,
          error_response: "REFUSED: Too many pending promotions."
        )

      event = Models.Switch.TriggerEvent.construct(raw)

      assert event.result == :FAILED
      assert event.error_response == "REFUSED: Too many pending promotions."
    end
  end

  describe ".preload_users" do
    test "preloads the author of an each trigger event" do
      switch = %Models.Switch{
        targets: [
          %Models.Switch.Target{
            events: [
              %Models.Switch.TriggerEvent{
                triggered_by: "9865c64d-783a-46e1-b659-2194b1d69494"
              },
              %Models.Switch.TriggerEvent{
                triggered_by: "78114608-be8a-465a-b9cd-81970fb802c7"
              },
              %Models.Switch.TriggerEvent{
                triggered_by: "78114608-be8a-465a-b9cd-81970fb802c7"
              }
            ]
          }
        ]
      }

      user_describe_many_response =
        InternalApi.User.DescribeManyResponse.new(
          status:
            InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
          users: [
            Support.Factories.user(id: "9865c64d-783a-46e1-b659-2194b1d69494"),
            Support.Factories.user(id: "78114608-be8a-465a-b9cd-81970fb802c7")
          ]
        )

      GrpcMock.stub(UserMock, :describe_many, user_describe_many_response)

      assert Models.Switch.preload_users(switch) == %Models.Switch{
               targets: [
                 %Models.Switch.Target{
                   events: [
                     %Models.Switch.TriggerEvent{
                       triggered_by: "9865c64d-783a-46e1-b659-2194b1d69494",
                       author:
                         Support.Factories.user(id: "9865c64d-783a-46e1-b659-2194b1d69494")
                         |> Models.User.construct()
                     },
                     %Models.Switch.TriggerEvent{
                       triggered_by: "78114608-be8a-465a-b9cd-81970fb802c7",
                       author:
                         Support.Factories.user(id: "78114608-be8a-465a-b9cd-81970fb802c7")
                         |> Models.User.construct()
                     },
                     %Models.Switch.TriggerEvent{
                       triggered_by: "78114608-be8a-465a-b9cd-81970fb802c7",
                       author:
                         Support.Factories.user(id: "78114608-be8a-465a-b9cd-81970fb802c7")
                         |> Models.User.construct()
                     }
                   ]
                 }
               ]
             }
    end
  end

  describe ".preload_pipelines" do
    test "returns switch with pipeline for each trigger event" do
      switch = %Models.Switch{
        targets: [
          %Models.Switch.Target{
            events: [
              %Models.Switch.TriggerEvent{
                pipeline_id: "9865c64d-783a-46e1-b659-2194b1d69494"
              },
              %Models.Switch.TriggerEvent{
                pipeline_id: "78114608-be8a-465a-b9cd-81970fb802c7"
              },
              %Models.Switch.TriggerEvent{
                pipeline_id: "3837d7j3-be8a-465a-b9cd-81970fb802c7"
              }
            ]
          }
        ]
      }

      describe_many_response =
        Plumber.DescribeManyResponse.new(
          response_status: Plumber.ResponseStatus.new(code: 0),
          pipelines: [
            Support.Factories.Pipeline.pipeline(ppl_id: "9865c64d-783a-46e1-b659-2194b1d69494"),
            Support.Factories.Pipeline.pipeline(ppl_id: "78114608-be8a-465a-b9cd-81970fb802c7"),
            Support.Factories.Pipeline.pipeline(ppl_id: "3837d7j3-be8a-465a-b9cd-81970fb802c7")
          ]
        )

      GrpcMock.stub(PipelineMock, :describe_many, describe_many_response)

      events =
        Models.Switch.preload_pipelines(switch).targets
        |> Enum.map(fn target -> target.events end)
        |> List.flatten()

      pipelines = Models.Pipeline.construct(describe_many_response.pipelines)

      Enum.each(events, fn event ->
        assert Enum.any?(pipelines, fn pipeline -> event.pipeline == pipeline end)
      end)
    end
  end
end
