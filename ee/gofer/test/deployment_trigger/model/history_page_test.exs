defmodule DeploymentTrigger.Model.HistoryPageTest do
  use ExUnit.Case, async: true
  alias Gofer.DeploymentTrigger.Model.DeploymentTrigger
  alias Gofer.DeploymentTrigger.Model.HistoryPage
  alias Gofer.Deployment.Model.Deployment
  alias Gofer.Switch.Model.Switch
  alias Gofer.EctoRepo

  require Logger

  setup [:truncate_database, :setup_target, :setup_switch]

  describe "load/1 when current_cursor == :FIRST" do
    test "and there are no triggers", ctx do
      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, :FIRST)

      assert Enum.empty?(results)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and has more triggers than page size", ctx do
      insert_triggers_for_past(ctx, 14, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, :FIRST)

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and has less triggers than page size", ctx do
      insert_triggers_for_past(ctx, 8, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, :FIRST)

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 9, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end
  end

  describe "load/1 when current_cursor == {:BEFORE, datetime}" do
    test "there are no triggers", ctx do
      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 6, :days)})

      assert Enum.empty?(results)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the only page", ctx do
      insert_triggers_for_past(ctx, 8, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 5, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 9, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 6, :hours)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is the nearly the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 1, :days)})

      assert_all_results_before?(ctx, results, 1, :days)
      assert_all_results_after?(ctx, results, 12, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 2, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 11, :days)
    end

    test "and overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 5, :days)})

      assert_all_results_before?(ctx, results, 5, :days)
      assert_all_results_after?(ctx, results, 16, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 6, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 15, :days)
    end

    test "and barely overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 9, :days)})

      assert_all_results_before?(ctx, results, 9, :days)
      assert_all_results_after?(ctx, results, 20, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 10, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 19, :days)
    end

    test "and nearly overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 10, :days)})

      assert_all_results_before?(ctx, results, 10, :days)
      assert_all_results_after?(ctx, results, 21, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 11, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 20, :days)
    end

    test "and is not the first page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 24, :days)})

      assert_all_results_before?(ctx, results, 24, :days)
      assert_all_results_after?(ctx, results, 35, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 25, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 34, :days)
    end

    test "and nearly overlaps the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 31, :days)})

      assert_all_results_before?(ctx, results, 31, :days)
      assert_all_results_after?(ctx, results, 42, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 32, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 41, :days)
    end

    test "and barely overlaps the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 32, :days)})

      assert_all_results_before?(ctx, results, 32, :days)
      assert_all_results_after?(ctx, results, 43, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 33, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 42, :days)
    end

    test "and overlaps the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 36, :days)})

      assert_all_results_before?(ctx, results, 36, :days)
      assert_all_results_after?(ctx, results, 47, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 37, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 46, :days)
    end

    test "and is the nearly the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 39, :days)})

      assert_all_results_before?(ctx, results, 39, :days)
      assert_all_results_after?(ctx, results, 50, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 40, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 49, :days)
    end

    test "and is the last page and has fewer than max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 44, :days)})

      assert_all_results_before?(ctx, results, 44, :days)
      assert_all_results_after?(ctx, results, 51, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 45, :days)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the last page and has exactly max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 40, :days)})

      assert_all_results_before?(ctx, results, 40, :days)
      assert_all_results_after?(ctx, results, 51, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 41, :days)
      assert_is_cursor_empty?(ctx, cursor_before)
    end
  end

  describe "load/1 when current_cursor == {:AFTER, datetime}" do
    test "there are no triggers", ctx do
      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 6, :days)})

      assert Enum.empty?(results)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the only page", ctx do
      insert_triggers_for_past(ctx, 7, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 5, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 9, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_empty?(ctx, cursor_before)
    end

    test "and is the latest page and would have had fewer than max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 9, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is the latest page and would have had slightly fewer than max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 10, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is the latest page and would have had max_size items", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 11, :days)})

      assert_all_results_before?(ctx, results, 0, :days)
      assert_all_results_after?(ctx, results, 11, :days)
      assert_is_cursor_empty?(ctx, cursor_after)
      assert_is_cursor_ago?(ctx, cursor_before, 10, :days)
    end

    test "and is nearly the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 12, :days)})

      assert_all_results_before?(ctx, results, 1, :days)
      assert_all_results_after?(ctx, results, 12, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 2, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 11, :days)
    end

    test "and overlaps the latest page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 17, :days)})

      assert_all_results_before?(ctx, results, 6, :days)
      assert_all_results_after?(ctx, results, 17, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 7, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 16, :days)
    end

    test "and is not the first page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 35, :days)})

      assert_all_results_before?(ctx, results, 24, :days)
      assert_all_results_after?(ctx, results, 35, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 25, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 34, :days)
    end

    test "and is nearly the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 50, :days)})

      assert_all_results_before?(ctx, results, 39, :days)
      assert_all_results_after?(ctx, results, 50, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 40, :days)
      assert_is_cursor_ago?(ctx, cursor_before, 49, :days)
    end

    test "and is the last page", ctx do
      insert_triggers_for_past(ctx, 50, :days)

      assert %HistoryPage{
               cursor_before: cursor_before,
               cursor_after: cursor_after,
               results: results
             } = load_page_with_cursor(ctx, {:AFTER, cursor_ago(ctx, 51, :days)})

      assert_all_results_before?(ctx, results, 40, :days)
      assert_all_results_after?(ctx, results, 51, :days)
      assert_is_cursor_ago?(ctx, cursor_after, 41, :days)
      assert_is_cursor_empty?(ctx, cursor_before)
    end
  end

  describe "load/1 with filters" do
    setup ctx do
      {:ok, switch: switch} = setup_switch(ctx, git_ref_type: "branch", label: "master")
      insert_triggers_for_past(%{ctx | switch: switch}, 15, :days)

      {:ok, switch: switch} = setup_switch(ctx, git_ref_type: "branch", label: "develop")
      insert_triggers_for_past(%{ctx | switch: switch}, 15, :days)

      {:ok, switch: switch} = setup_switch(ctx, git_ref_type: "tag", label: "v1.0.0")
      insert_triggers_for_past(%{ctx | switch: switch}, 15, :days)

      {:ok, switch: switch} = setup_switch(ctx, git_ref_type: "tag", label: "latest")
      insert_triggers_for_past(%{ctx | switch: switch}, 15, :days)

      {:ok, switch: switch} = setup_switch(ctx, git_ref_type: "pr", label: "1")
      insert_triggers_for_past(%{ctx | switch: switch}, 15, :days)

      ctx
    end

    test "for all branches", ctx do
      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)},
                 git_ref_type: "branch"
               )

      assert Enum.all?(results, &(&1.git_ref_type == "branch"))
      assert Enum.any?(results, &(&1.git_ref_label == "master"))
      assert Enum.any?(results, &(&1.git_ref_label == "develop"))
    end

    test "filters for particular name", ctx do
      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)},
                 git_ref_type: "branch",
                 git_ref_label: "master"
               )

      assert Enum.all?(results, &(&1.git_ref_type == "branch"))
      assert Enum.any?(results, &(&1.git_ref_label == "master"))
      refute Enum.any?(results, &(&1.git_ref_label == "develop"))
    end

    test "filters for all tags", ctx do
      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)},
                 git_ref_type: "tag"
               )

      assert Enum.all?(results, &(&1.git_ref_type == "tag"))
      assert Enum.any?(results, &(&1.git_ref_label == "latest"))
      assert Enum.any?(results, &(&1.git_ref_label == "v1.0.0"))
    end

    test "filters for particular tag", ctx do
      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)},
                 git_ref_type: "tag",
                 git_ref_label: "latest"
               )

      assert Enum.all?(results, &(&1.git_ref_type == "tag"))
      assert Enum.any?(results, &(&1.git_ref_label == "latest"))
      refute Enum.any?(results, &(&1.git_ref_label == "v1.0.0"))
    end

    test "filters for all pull requests", ctx do
      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, {:BEFORE, cursor_ago(ctx, 2, :days)}, git_ref_type: "pr")

      assert Enum.all?(results, &(&1.git_ref_type == "pr"))
    end

    test "filters for particular triggerer", ctx do
      triggerer_id = UUID.uuid4()

      for i <- Range.new(20, 25) do
        insert_trigger(ctx,
          target_name: "Target#{i}",
          triggered_by: triggerer_id,
          triggered_at: ago(ctx.now, i, :hours)
        )
      end

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, triggered_by: triggerer_id)

      assert Enum.all?(results, &(&1.triggered_by == triggerer_id))
      assert Enum.count(results) == 6
    end

    test "filters with parameter1 set", ctx do
      for i <- Range.new(1, 7),
          do: insert_trigger(ctx, triggered_at: ago(ctx.now, i, :hours), parameter1: "test")

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, parameter1: "test")

      assert Enum.count(results) == 7
    end

    test "filters with parameter2 set", ctx do
      for i <- Range.new(1, 7),
          do: insert_trigger(ctx, triggered_at: ago(ctx.now, i, :hours), parameter2: "test")

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, parameter2: "test")

      assert Enum.count(results) == 7
    end

    test "filters with parameter3 set", ctx do
      for i <- Range.new(1, 7),
          do: insert_trigger(ctx, triggered_at: ago(ctx.now, i, :hours), parameter3: "test")

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, parameter3: "test")

      assert Enum.count(results) == 7
    end

    test "filters with parameter1 set using regex", ctx do
      for i <- Range.new(1, 7),
          do:
            insert_trigger(ctx, triggered_at: ago(ctx.now, i, :hours), parameter1: "testwithregex")

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, parameter1: "t(e)?stwith.*")

      assert Enum.count(results) == 7
    end

    test "filters with parameter1 set using unsafe regexes should not match", ctx do
      unsafe_regexes = [
        "(te+stwithregex)+",
        "(t.*)+withregex",
        "(te|tes|test|testw|testwi|testwit|testwith)+regex",
        "(te|test)*withregex",
        "(?=testwith)regex",
        "(?<=test)withregex"
      ]

      unsafe_regexes
      |> Enum.each(fn regex ->
        for i <- Range.new(1, 3),
            do:
              insert_trigger(ctx,
                triggered_at: ago(ctx.now, i, :hours),
                parameter1: "testwithregex"
              )

        Logger.debug("Regex: #{regex}")

        assert %HistoryPage{results: results} =
                 load_page_with_cursor(ctx, :FIRST, parameter1: regex)

        assert Enum.count(results) == 0
      end)
    end

    test "filters with parameter1 set using * wildcard", ctx do
      for i <- Range.new(1, 7),
          do:
            insert_trigger(ctx,
              triggered_at: ago(ctx.now, i, :hours),
              parameter1: "testwithwildcard"
            )

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, parameter1: "testwithwild*")

      assert Enum.count(results) == 7
    end

    test "filters with parameter1 set using % wildcard", ctx do
      for i <- Range.new(1, 7),
          do:
            insert_trigger(ctx,
              triggered_at: ago(ctx.now, i, :hours),
              parameter1: "testwithwildcard"
            )

      assert %HistoryPage{results: results} =
               load_page_with_cursor(ctx, :FIRST, parameter1: "testwithwild%")

      assert Enum.count(results) == 7
    end
  end

  defp assert_is_cursor_ago?(ctx, cursor, amount, unit) do
    assert ctx.now |> ago(amount, unit) |> DateTime.truncate(:microsecond) ==
             DateTime.from_unix!(cursor, :microsecond)
  end

  defp assert_is_cursor_empty?(_ctx, cursor), do: is_nil(cursor)

  defp assert_all_results_before?(ctx, results, amount, unit) do
    compare_all_before? = fn datetimes, datetime ->
      Enum.all?(datetimes, &(DateTime.diff(&1, datetime) < 0))
    end

    assert compare_all_before?.(
             Enum.map(results, & &1.triggered_at),
             ctx.now |> ago(amount, unit)
           )
  end

  defp assert_all_results_after?(ctx, results, amount, unit) do
    compare_all_after? = fn datetimes, datetime ->
      Enum.all?(datetimes, &(DateTime.diff(&1, datetime) > 0))
    end

    assert compare_all_after?.(
             Enum.map(results, & &1.triggered_at),
             ctx.now |> ago(amount, unit)
           )
  end

  defp insert_triggers_for_past(ctx, amount, unit) do
    for i <- Range.new(1, amount) do
      insert_trigger(ctx,
        target_name: "Target#{i}",
        triggered_at: ago(ctx.now, i, unit)
      )
    end
  end

  defp load_page_with_cursor(ctx, cursor, filters \\ []) do
    HistoryPage.load(%HistoryPage{
      deployment_id: ctx.target.id,
      current_cursor: cursor,
      filters: Map.new(filters),
      max_size: 10
    })
  end

  defp cursor_ago(ctx, amount, unit),
    do: ctx.now |> ago(amount, unit) |> DateTime.to_unix(:microsecond)

  defp ago(now, amount, :seconds), do: DateTime.add(now, -amount)
  defp ago(now, amount, :minutes), do: ago(now, amount * 60, :seconds)
  defp ago(now, amount, :hours), do: ago(now, amount * 60, :minutes)
  defp ago(now, amount, :days), do: ago(now, amount * 24, :hours)

  defp truncate_database(_context) do
    {:ok, %Postgrex.Result{}} = EctoRepo.query("TRUNCATE TABLE deployment_triggers CASCADE;")
    {:ok, now: DateTime.utc_now()}
  end

  defp setup_target(_context) do
    target =
      %Deployment{}
      |> Deployment.changeset(%{
        name: "DeploymentTarget",
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        unique_token: UUID.uuid4(),
        created_by: UUID.uuid4(),
        updated_by: UUID.uuid4(),
        subject_rules: [%{type: :ANY, subject_id: ""}],
        object_rules: [%{type: :BRANCH, match_mode: :ALL, pattern: ""}]
      })
      |> Ecto.Changeset.put_change(:state, :FINISHED)
      |> Ecto.Changeset.put_change(:result, :SUCCESS)
      |> EctoRepo.insert!()

    {:ok, target: target}
  end

  defp setup_switch(_context, extra \\ []) do
    switch =
      %Switch{}
      |> Switch.changeset(%{
        id: UUID.uuid4(),
        ppl_id: UUID.uuid4(),
        prev_ppl_artefact_ids: [UUID.uuid4()],
        branch_name: "master",
        git_ref_type: extra[:git_ref_type] || "branch",
        label: extra[:label] || "master"
      })
      |> EctoRepo.insert!()

    {:ok, switch: switch}
  end

  defp insert_trigger(context, extra) do
    triggered_at = extra[:triggered_at] || DateTime.utc_now()
    triggered_by = extra[:triggered_by] || UUID.uuid4()
    request_token = extra[:request_token] || UUID.uuid4()
    target_name = extra[:target_name] || "Target"
    switch_trigger_id = UUID.uuid4()

    switch_trigger_params = %{
      "id" => switch_trigger_id,
      "switch_id" => context.switch.id,
      "request_token" => request_token,
      "target_names" => [target_name],
      "triggered_by" => triggered_by,
      "triggered_at" => triggered_at,
      "auto_triggered" => false,
      "override" => false,
      "env_vars_for_target" => %{},
      "processed" => false
    }

    defaults = %{
      deployment_id: context.target.id,
      switch_id: context.switch.id,
      git_ref_type: context.switch.git_ref_type,
      git_ref_label: context.switch.label,
      triggered_by: triggered_by,
      triggered_at: triggered_at,
      switch_trigger_id: switch_trigger_id,
      target_name: target_name,
      request_token: request_token,
      switch_trigger_params: switch_trigger_params,
      parameter1: extra[:parameter1],
      parameter2: extra[:parameter2],
      parameter3: extra[:parameter3]
    }

    EctoRepo.insert!(struct!(DeploymentTrigger, defaults))
  end
end
