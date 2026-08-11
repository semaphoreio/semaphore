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

  describe ".job_timer_placeholder?/1" do
    test "returns true for a finished pipeline job that never started" do
      job = %{
        state: :FINISHED,
        started_at: nil,
        finished_at: 1_715_000_000
      }

      assert PipelineView.job_timer_placeholder?(job)
      assert PipelineView.job_timer_label(job) == "--:--"
    end

    test "returns true for an after-pipeline job that is done but has no state key" do
      job = %{
        id: "431255a4-140c-4542-97d6-adda565d1516",
        name: "Generate workflow markdown report",
        done?: true,
        failed?: true,
        started_at: nil,
        done_at: 1_773_846_018
      }

      assert PipelineView.job_timer_placeholder?(job)
      assert PipelineView.job_timer_label(job) == "--:--"
    end

    test "returns false and formats duration when execution actually started" do
      job = %{
        state: :FINISHED,
        started_at: %{seconds: 1_714_999_900},
        finished_at: %{seconds: 1_715_000_000}
      }

      refute PipelineView.job_timer_placeholder?(job)
      assert PipelineView.job_timer_label(job) == "01:40"
    end
  end

  describe ".reused_job?" do
    test "true only for jobs carrying original_job_id lineage" do
      assert PipelineView.reused_job?(%{original_job_id: "0561a1e6-e669-4b71-a752-a1e6a1a05a1e"})
      refute PipelineView.reused_job?(%{original_job_id: ""})
      refute PipelineView.reused_job?(%{original_job_id: nil})
      refute PipelineView.reused_job?(%{})
    end
  end

  describe ".reused_block?" do
    test "true only for blocks whose task ran in another pipeline" do
      assert PipelineView.reused_block?(%{reused_from: "b1e2a3c4-5d6e-4f70-8a9b-0c1d2e3f4a5b"})

      refute PipelineView.reused_block?(%{reused_from: ""})
      refute PipelineView.reused_block?(%{reused_from: nil})
      refute PipelineView.reused_block?(%{})
    end
  end

  describe ".job_link_id" do
    test "points at the original job when the job carries lineage" do
      assert PipelineView.job_link_id(%{
               id: "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
               original_job_id: "0561a1e6-e669-4b71-a752-a1e6a1a05a1e"
             }) == "0561a1e6-e669-4b71-a752-a1e6a1a05a1e"
    end

    test "points at the job itself without lineage" do
      id = "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

      assert PipelineView.job_link_id(%{id: id, original_job_id: ""}) == id
      assert PipelineView.job_link_id(%{id: id, original_job_id: nil}) == id
      assert PipelineView.job_link_id(%{id: id}) == id
    end
  end

  defp graph_block(attrs) do
    %{
      name: "Build",
      skipped?: false,
      result_reason: nil,
      reused_from: nil,
      jobs: [graph_job(%{})]
    }
    |> Map.merge(attrs)
  end

  defp render_graph_block(block) do
    conn = build_conn() |> Plug.Conn.assign(:organization_id, "org-1")

    render_to_string(PipelineView, "_block.html", block: block, conn: conn)
  end

  describe "_block.html reused-block rendering" do
    test "every job of a reused block gets the reused treatment, the block itself stays plain" do
      html =
        render_graph_block(graph_block(%{reused_from: "b1e2a3c4-5d6e-4f70-8a9b-0c1d2e3f4a5b"}))

      assert html =~ "job-reused"
      assert html =~ "data-tippy-content"
      assert html =~ "was not re-executed"
      # a reused job shows the placeholder timer in its status colour, not a duration
      assert html =~ ~s(class="f5 code green">--:--)
      refute html =~ "01:40"
      # the card itself is not dimmed and carries no marker of its own
      refute html =~ "block-reused"
      refute html =~ "carried over"
    end

    test "a regular block renders its jobs untouched" do
      html = render_graph_block(graph_block(%{}))

      assert html =~ "01:40"
      refute html =~ "job-reused"
      refute html =~ "was not re-executed"
    end

    test "a block without the reuse field renders its jobs untouched" do
      html = render_graph_block(graph_block(%{}) |> Map.delete(:reused_from))

      assert html =~ "01:40"
      refute html =~ "job-reused"
      refute html =~ "was not re-executed"
    end
  end

  defp graph_job(attrs) do
    %{
      id: "6ba7b810-9dad-11d1-80b4-00c04fd430c8",
      name: "unit tests",
      state: :FINISHED,
      result: :PASSED,
      original_job_id: "",
      started_at: %{seconds: 1_714_999_900},
      finished_at: %{seconds: 1_715_000_000}
    }
    |> Map.merge(attrs)
  end

  defp render_graph_job(job) do
    conn = build_conn() |> Plug.Conn.assign(:organization_id, "org-1")

    render_to_string(PipelineView, "_job.html",
      job: job,
      conn: conn,
      block_result_reason: nil
    )
  end

  describe "_job.html reused-job rendering" do
    test "a reused job dims, shows the placeholder timer, and links to the original job" do
      html =
        render_graph_job(graph_job(%{original_job_id: "0561a1e6-e669-4b71-a752-a1e6a1a05a1e"}))

      assert html =~ "job-reused"
      assert html =~ "data-tippy-content"
      assert html =~ "was not re-executed"
      assert html =~ ~s(class="f5 code green">--:--)
      assert html =~ "/jobs/0561a1e6-e669-4b71-a752-a1e6a1a05a1e"
      refute html =~ "/jobs/6ba7b810-9dad-11d1-80b4-00c04fd430c8"
      refute html =~ "01:40"
    end

    test "a regular job renders its duration and links to itself" do
      html = render_graph_job(graph_job(%{}))

      assert html =~ "01:40"
      assert html =~ "/jobs/6ba7b810-9dad-11d1-80b4-00c04fd430c8"
      refute html =~ "job-reused"
      refute html =~ "was not re-executed"
    end

    test "a job without the lineage field renders untouched" do
      html = render_graph_job(graph_job(%{}) |> Map.delete(:original_job_id))

      assert html =~ "01:40"
      assert html =~ "/jobs/6ba7b810-9dad-11d1-80b4-00c04fd430c8"
      refute html =~ "job-reused"
      refute html =~ "was not re-executed"
    end

    test "a job in a reused block gets the same treatment without lineage of its own" do
      conn = build_conn() |> Plug.Conn.assign(:organization_id, "org-1")

      html =
        render_to_string(PipelineView, "_job.html",
          job: graph_job(%{}),
          conn: conn,
          block_result_reason: nil,
          block_reused?: true
        )

      assert html =~ "job-reused"
      assert html =~ ~s(class="f5 code green">--:--)
      # no lineage, so the row still points at the job itself
      assert html =~ "/jobs/6ba7b810-9dad-11d1-80b4-00c04fd430c8"
      refute html =~ "01:40"
    end
  end
end
