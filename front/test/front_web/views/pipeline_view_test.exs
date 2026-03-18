defmodule FrontWeb.PipelineViewTest do
  use FrontWeb.ConnCase
  import Phoenix.View, only: [render_to_string: 3]
  alias Front.Models
  alias FrontWeb.PipelineView
  alias Support.Factories

  describe ".format_triggerer" do
    test "for an initial workflow" do
      pipeline =
        Factories.pipeline_with_trigger(:INITIAL_WORKFLOW)
        |> Models.Pipeline.construct()

      result = PipelineView.format_triggerer(build_conn(), nil, pipeline)

      assert result == "Triggered by push by provider_login"
    end

    test "for an api run" do
      pipeline =
        Factories.pipeline_with_trigger(:API)
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          owner: {:user, {"1", "foo"}}
        })

      result = PipelineView.format_triggerer(build_conn(), nil, pipeline)

      assert result == "Triggered by API call by foo"
    end

    test "for a scheduled run" do
      pipeline =
        Factories.pipeline_with_trigger(:SCHEDULED_RUN)
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          owner: {:user, {"1", "foo"}}
        })

      result = PipelineView.format_triggerer(build_conn(), %{project_name: "foo"}, pipeline)

      assert result =~ ~r/Scheduled run of a .*Task.* by foo/
    end

    test "for a scheduled manual run" do
      pipeline =
        Factories.pipeline_with_trigger(:SCHEDULED_MANUAL_RUN)
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          owner: {:user, {"1", "foo"}}
        })

      result = PipelineView.format_triggerer(build_conn(), %{project_name: "foo"}, pipeline)
      assert result =~ ~r/Manual run of a .*Task.* by foo/
    end

    test "for a partial pipeline rerun" do
      pipeline =
        Factories.pipeline_with_trigger(:PIPELINE_PARTIAL_RERUN)
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          owner: {:user, {"1", "foo"}}
        })

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Partial rerun of a .*Pipeline.* by foo/
    end

    test "for a workflow rerun" do
      pipeline =
        Factories.pipeline_with_trigger(:WORKFLOW_RERUN)
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          owner: {:user, {"1", "foo"}}
        })

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Triggered by rerun of a .*Workflow.* by foo/
    end

    test "for a manual promotion" do
      pipeline =
        Factories.pipeline_with_trigger(:MANUAL_PROMOTION)
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          owner: {:user, {"1", "foo"}}
        })

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Manual promotion by foo/
    end

    test "for an auto promotion" do
      pipeline =
        Factories.pipeline_with_trigger(:AUTO_PROMOTION)
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          owner: {:user, {"1", "foo"}}
        })

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Auto promoted/
    end

    test "displays termination info" do
      alias InternalApi.Plumber.Pipeline.Result, as: PplResult

      pipeline =
        Factories.pipeline()
        |> Models.Pipeline.construct()

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      refute result =~ ~r/Stopped/

      pipeline =
        Factories.pipeline()
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          terminated_by: {:name, "admin"},
          is_terminated?: true
        })

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Stopped by admin/

      pipeline =
        Factories.pipeline()
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          terminated_by: {:name, "branch deletion"},
          is_terminated?: true
        })

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Stopped by branch deletion/

      pipeline =
        Factories.pipeline()
        |> Models.Pipeline.construct()
        |> update_triggerer(%{
          terminated_by: {:user, {"1", "foo"}},
          is_terminated?: true
        })

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Stopped by foo/

      pipeline =
        Factories.pipeline()
        |> Map.merge(%{result: PplResult.value(:STOPPED)})
        |> Models.Pipeline.construct()

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Stopped/

      pipeline =
        Factories.pipeline()
        |> Map.merge(%{result: PplResult.value(:CANCELED)})
        |> Models.Pipeline.construct()

      result =
        PipelineView.format_triggerer(build_conn(), %{id: "123", project_name: "foo"}, pipeline)

      assert result =~ ~r/Stopped/
    end
  end

  defp update_triggerer(pipeline, triggerer_update) do
    triggerer = Map.merge(pipeline.triggerer, triggerer_update)
    %{pipeline | triggerer: triggerer}
  end

  describe "switch/_target_form.html" do
    test "renders promotion attributes correctly when the target name includes single quotes", %{
      conn: conn
    } do
      html =
        render_to_string(PipelineView, "switch/_target_form.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: %{id: "sw-1"},
          target: %{name: "Publish 'my-package' to Production", parameters: []}
        })

      assert html =~ ~s(data-promotion-target="Publish &#39;my-package&#39; to Production")
      assert html =~ ~s(data-switch="sw-1")
      assert html =~ ~s(promote-confirmation)
    end

    test "escapes double quotes inside promotion target names", %{conn: conn} do
      target_name = ~s(Publish "critical" to Production)

      html =
        render_to_string(PipelineView, "switch/_target_form.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: %{id: "sw-1"},
          target: %{name: target_name, parameters: []}
        })

      assert html =~ ~s(data-promotion-target="Publish &quot;critical&quot; to Production")
      assert html =~ ~s(Start promotion)
    end

    test "handles promotion target names with unicode emoji", %{conn: conn} do
      target_name = "Deploy 🚀 to Production"

      html =
        render_to_string(PipelineView, "switch/_target_form.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: %{id: "sw-1"},
          target: %{name: target_name, parameters: []}
        })

      assert html =~ ~s(data-promotion-target="Deploy 🚀 to Production")
      assert html =~ ~s(promote-confirmation)
    end

    test "handles promotion target names with accented characters", %{conn: conn} do
      target_name = "Déploiement en Français"

      html =
        render_to_string(PipelineView, "switch/_target_form.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: %{id: "sw-1"},
          target: %{name: target_name, parameters: []}
        })

      assert html =~ ~s(data-promotion-target="Déploiement en Français")
      assert html =~ ~s(promote-confirmation)
    end

    test "handles promotion target names with CJK characters", %{conn: conn} do
      target_name = "部署到生产环境"

      html =
        render_to_string(PipelineView, "switch/_target_form.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: %{id: "sw-1"},
          target: %{name: target_name, parameters: []}
        })

      assert html =~ ~s(data-promotion-target="部署到生产环境")
      assert html =~ ~s(promote-confirmation)
    end

    test "handles promotion target names with mixed unicode and special characters", %{conn: conn} do
      target_name = "Deploy 'app' 🎉 to Staging"

      html =
        render_to_string(PipelineView, "switch/_target_form.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: %{id: "sw-1"},
          target: %{name: target_name, parameters: []}
        })

      assert html =~ ~s(data-promotion-target="Deploy &#39;app&#39; 🎉 to Staging")
      assert html =~ ~s(promote-confirmation)
    end

    test "handles CSS selector metacharacters in target names", %{conn: conn} do
      target_name = "Deploy[test]:value.class#id"

      html =
        render_to_string(PipelineView, "switch/_target_form.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: %{id: "sw-1"},
          target: %{name: target_name, parameters: []}
        })

      assert html =~ ~s(data-promotion-target=)
      assert html =~ ~s(promote-confirmation)
    end
  end

  describe "pipeline/_switch.html" do
    test "renders failed promotion reason when error response exists", %{conn: conn} do
      switch = %Models.Switch{
        id: "sw-1",
        targets: [
          %Models.Switch.Target{
            switch_id: "sw-1",
            name: "prod",
            parameters: [],
            deployment: nil,
            events: [
              %Models.Switch.TriggerEvent{
                processed: true,
                result: :FAILED,
                triggered_at: 1_700_000_000,
                auto_triggered: false,
                error_response: "REFUSED: Too many pending promotions.",
                author: %Models.User{name: "alex"}
              }
            ]
          }
        ]
      }

      html =
        render_to_string(PipelineView, "_switch.html", %{
          conn: conn,
          workflow: %{id: "wf-1"},
          pipeline: %{id: "pl-1"},
          switch: switch,
          selected_trigger_event_id: nil,
          can_promote?: true
        })

      assert html =~ "Failed to promote"
      assert html =~ "REFUSED: Too many pending promotions."
    end
  end

  describe ".action_string" do
    test "when the pipeline is terminated by a user => shows correct message" do
      terminator = %Models.User{
        name: "awesome user"
      }

      pipeline = %Models.Pipeline{
        terminated_by: "a8114608-be8a-465a-b9cd-81970fb802c6",
        terminator: terminator
      }

      action = PipelineView.action_string(nil, nil, pipeline)
      assert action == "Stopped by awesome user"
    end

    test "when the pipeline is terminated by admin => shows correct message" do
      pipeline = %Models.Pipeline{
        terminated_by: "admin"
      }

      action = PipelineView.action_string(nil, nil, pipeline)
      assert action == "Stopped by Semaphore"
    end

    test "when the pipeline is terminated by branch deletion => shows correct messgae" do
      pipeline = %Models.Pipeline{
        terminated_by: "branch deletion"
      }

      action = PipelineView.action_string(nil, nil, pipeline)
      assert action == "Stopped by branch deletion"
    end

    test "when the pipeline is terminated by unknown cause => shows correct message" do
      pipeline = %Models.Pipeline{
        terminated_by: "voodoo"
      }

      action = PipelineView.action_string(nil, nil, pipeline)
      assert action == "Stopped"
    end

    test "when the pipeline is not terminated, a rerun or a promotion => reverts to trigger message" do
      workflow = %Models.Workflow{
        triggered_by: :SCHEDULE,
        rerun_of: ""
      }

      pipeline = %Models.Pipeline{
        terminated_by: "",
        partial_rerun_of: ""
      }

      action = PipelineView.action_string(nil, workflow, pipeline)
      assert action =~ "Triggered"
    end
  end

  describe ".pipeline_rebuildable?" do
    test "returns true when pipeline is in DONE state" do
      pipeline = %Models.Pipeline{state: :DONE}
      assert PipelineView.pipeline_rebuildable?(pipeline) == true
    end

    test "returns false when pipeline is in PENDING state" do
      pipeline = %Models.Pipeline{state: :PENDING}
      assert PipelineView.pipeline_rebuildable?(pipeline) == false
    end

    test "returns false when pipeline is in RUNNING state" do
      pipeline = %Models.Pipeline{state: :RUNNING}
      assert PipelineView.pipeline_rebuildable?(pipeline) == false
    end

    test "returns false when pipeline is in STOPPING state" do
      pipeline = %Models.Pipeline{state: :STOPPING}
      assert PipelineView.pipeline_rebuildable?(pipeline) == false
    end
  end
end
