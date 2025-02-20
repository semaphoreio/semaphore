defmodule HooksProcessor.Hooks.Processing.Resurrector.Test do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Processing.WorkersSupervisor
  alias HooksProcessor.Hooks.Processing.Resurrector
  alias HooksProcessor.Hooks.Model.HooksQueries

  setup do
    start_supervised!(WorkersSupervisor)

    Test.Helpers.truncate_db()

    params = %{
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      webhook: %{"hello" => "world"},
      provider: "test",
      repository_id: UUID.uuid4(),
      received_at: DateTime.utc_now()
    }

    {:ok, %{request: params}}
  end

  defp hook_to_launching_state do
    fn state ->
      assert %{id: id} = state

      assert {:ok, hook} = HooksQueries.get_by_id(id)

      params = %{
        wf_id: UUID.uuid4(),
        ppl_id: UUID.uuid4(),
        branch_id: UUID.uuid4(),
        commit_sha: "daf07dd85350b95d05a7fe898e07022c5dcd95b9",
        git_ref: "refs/heads/master",
        commit_author: "bitbucket_username"
      }

      assert {:ok, _hook} = HooksQueries.update_webhook(hook, params, "launching")

      {:stop, :normal, state}
    end
  end

  test "resurrector starts workers for all hooks that are stuck in processing too long", ctx do
    func = hook_to_launching_state()
    Application.put_env(:hooks_processor, :test_worker_func, func)

    assert {:ok, h0} = insert(ctx, "processing", :older_than_a_day)
    assert {:ok, h1} = insert(ctx, "processing", :less_than_a_day_old)
    assert {:ok, h2} = insert(ctx, "processing", :less_than_a_day_old)
    assert {:ok, h3} = insert(ctx, "processing", :less_than_15s_old)
    assert {:ok, h4} = insert(ctx, "launching", :older_than_a_day)
    assert {:ok, h5} = insert(ctx, "launching", :less_than_a_day_old)
    assert {:ok, h6} = insert(ctx, "launching", :less_than_15s_old)

    start_supervised!(Resurrector)

    :timer.sleep(6_000)

    assert {:ok, h0} == HooksQueries.get_by_id(h0.id)

    assert {:ok, hook} = HooksQueries.get_by_id(h1.id)
    assert hook.state == "launching"
    assert {:ok, _info} = UUID.info(hook.wf_id)
    assert {:ok, _info} = UUID.info(hook.ppl_id)

    assert {:ok, hook} = HooksQueries.get_by_id(h2.id)
    assert hook.state == "launching"
    assert {:ok, _info} = UUID.info(hook.wf_id)
    assert {:ok, _info} = UUID.info(hook.ppl_id)

    assert {:ok, h3} == HooksQueries.get_by_id(h3.id)
    assert {:ok, h4} == HooksQueries.get_by_id(h4.id)
    assert {:ok, h5} == HooksQueries.get_by_id(h5.id)
    assert {:ok, h6} == HooksQueries.get_by_id(h6.id)
  end

  defp insert(ctx, state, timeframe) do
    payload = "#{state}-#{timeframe}"

    params = %{
      received_at: DateTime.utc_now(),
      inserted_at: timestamp(timeframe),
      webhook: %{"id" => payload}
    }

    {:ok, hook} =
      ctx.request
      |> Map.merge(params)
      |> HooksQueries.insert()

    assert {:ok, _hook} = HooksQueries.update_webhook(hook, %{}, state)
  end

  defp timestamp(timeframe) do
    DateTime.utc_now() |> DateTime.add(amount(timeframe), :second)
  end

  # 26h in seconds
  defp amount(:older_than_a_day), do: -26 * 60 * 60
  # 16h in seconds
  defp amount(:less_than_a_day_old), do: -16 * 60 * 60
  defp amount(:less_than_15s_old), do: -3
end
