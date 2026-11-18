defmodule FrontWeb.WorkflowViewTest do
  use FrontWeb.ConnCase
  alias Front.Models
  alias FrontWeb.{PipelineView, WorkflowView}
  alias Support.Factories

  describe "render map.json" do
    setup do
      Support.Stubs.init()
      Support.Stubs.build_shared_factories()

      conn =
        build_conn()
        |> assign(:permissions, %{})
        |> assign(:anonymous, false)
        |> assign(:organization_id, Support.Stubs.DB.first(:organizations).id)

      [conn: conn]
    end

    defp pipeline(trigger, triggerer_update) do
      pipeline = trigger |> Factories.pipeline_with_trigger() |> Models.Pipeline.construct()
      %{pipeline | triggerer: Map.merge(pipeline.triggerer, triggerer_update)}
    end

    defp render_map(conn, pipeline) do
      workflow = %{
        id: "wf-1",
        project_name: "foo",
        root_pipeline_id: pipeline.id,
        pipelines: [pipeline]
      }

      json = WorkflowView.render("map.json", %{workflow: workflow, conn: conn})
      {workflow, hd(json.pipelines).triggerer}
    end

    defp as_words(triggerer) do
      stopped =
        triggerer.stopped &&
          if(triggerer.stopped_by,
            do: "- Stopped by #{triggerer.stopped_by}",
            else: "- Stopped"
          )

      [
        triggerer.text,
        triggerer.link && triggerer.link.label,
        triggerer.owner && "by #{triggerer.owner}",
        stopped
      ]
      |> Enum.filter(& &1)
      |> Enum.join(" ")
    end

    test "says how, by whom and who stopped each pipeline in the words of the old tree", %{
      conn: conn
    } do
      triggers = [
        :INITIAL_WORKFLOW,
        :WORKFLOW_RERUN,
        :API,
        :SCHEDULED_RUN,
        :SCHEDULED_MANUAL_RUN,
        :PIPELINE_PARTIAL_RERUN,
        :MANUAL_PROMOTION,
        :AUTO_PROMOTION
      ]

      endings = [
        %{},
        %{is_terminated?: true, terminated_by: {:user, {"2", "Bo"}}},
        %{is_terminated?: true, terminated_by: {:name, "branch deletion"}},
        %{is_terminated?: true, terminated_by: :none}
      ]

      for trigger <- triggers, ending <- endings, owner <- [{:user, {"1", "Ana"}}, :none] do
        pipeline = pipeline(trigger, Map.put(ending, :owner, owner))
        {workflow, triggerer} = render_map(conn, pipeline)
        old = PipelineView.format_triggerer(conn, workflow, pipeline)

        assert as_words(triggerer) == String.replace(old, ~r/<[^>]*>/, ""),
               "#{trigger} #{inspect(ending)} #{inspect(owner)}"

        case Regex.run(~r/href="([^"]+)"/, old) do
          [_, href] -> assert triggerer.link.url == href
          nil -> assert triggerer.link == nil
        end
      end
    end

    test "sends names as they are, for the map to escape, and names a deleted user", %{conn: conn} do
      {_, triggerer} =
        render_map(
          conn,
          pipeline(:API, %{
            owner: {:user, {"1", "<b>Ana</b>"}},
            is_terminated?: true,
            terminated_by: {:user, {"2", ""}}
          })
        )

      assert triggerer.owner == "<b>Ana</b>"
      assert triggerer.stopped_by == "[Deleted User]"
    end

    test "sends why a pipeline ended", %{conn: conn} do
      pipeline = %{pipeline(:API, %{}) | state: :DONE, result: :STOPPED, result_reason: :STRATEGY}

      workflow = %{
        id: "wf-1",
        project_name: "foo",
        root_pipeline_id: pipeline.id,
        pipelines: [pipeline]
      }

      [json] = WorkflowView.render("map.json", %{workflow: workflow, conn: conn}).pipelines

      assert {json.result, json.result_reason} == {:STOPPED, :STRATEGY}
    end
  end
end
