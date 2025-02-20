defmodule HooksProcessor.Hooks.Model.HooksQueries.Test do
  use ExUnit.Case

  alias HooksProcessor.Hooks.Model.HooksQueries

  setup do
    Test.Helpers.truncate_db()

    params = %{
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      webhook: %{"hello" => "world"},
      provider: "bitbucket",
      repository_id: UUID.uuid4(),
      received_at: DateTime.utc_now()
    }

    {:ok, %{request: params}}
  end

  # insert

  test "can not insert a hook if some of the required fields are missing", ctx do
    ~w(project_id webhook provider repository_id received_at)a
    |> Enum.map(fn field ->
      request = Map.delete(ctx.request, field)

      assert {:error, _message} = HooksQueries.insert(request)
    end)
  end

  test "can not insert a hook if provider field value is invalid", ctx do
    request = %{ctx.request | provider: "invalid_value"}

    assert {:error, _message} = HooksQueries.insert(request)
  end

  test "when all data is valid the hook is inserted in the database", ctx do
    assert {:ok, hook} = HooksQueries.insert(ctx.request)

    assert {:ok, hook2} = HooksQueries.get_by_id(hook.id)

    assert hook == hook2
  end

  test "insert is idempotent operation", ctx do
    assert {:ok, hook1} = HooksQueries.insert(ctx.request)
    assert {:ok, hook2} = HooksQueries.insert(ctx.request)

    assert hook1 == hook2
  end

  # update

  test "update is successful when given valid hook and update params", ctx do
    assert {:ok, hook} = HooksQueries.insert(ctx.request)

    params = %{
      wf_id: UUID.uuid4(),
      ppl_id: UUID.uuid4(),
      branch_id: UUID.uuid4(),
      commit_sha: "daf07dd85350b95d05a7fe898e07022c5dcd95b9",
      git_ref: "refs/heads/master",
      commit_author: "bitbucket_username"
    }

    assert {:ok, hook} = HooksQueries.update_webhook(hook, params, "launching")

    assert hook.state == "launching"
    assert hook.result == "OK"
    assert hook.wf_id == params.wf_id
    assert hook.ppl_id == params.ppl_id
    assert hook.branch_id == params.branch_id
    assert hook.commit_sha == "daf07dd85350b95d05a7fe898e07022c5dcd95b9"
    assert hook.git_ref == "refs/heads/master"
    assert hook.commit_author == "bitbucket_username"
  end

  # get_by_id

  test "get_by_id returns {:ok, hook} when hook with a given id exists", ctx do
    assert {:ok, hook1} = HooksQueries.insert(ctx.request)
    assert {:ok, hook2} = HooksQueries.get_by_id(hook1.id)

    assert hook1 == hook2
  end

  test "get_by_id returns {:error, message} when hook with a given id does not exist" do
    id = UUID.uuid4()
    assert {:error, message} = HooksQueries.get_by_id(id)
    assert message == "Hook with an id: #{id} not found."
  end

  # get_by_repo_received_at

  test "get_by_repo_received_at returns {:ok, hook} when hook with given data exists", ctx do
    assert {:ok, h1} = HooksQueries.insert(ctx.request)
    assert {:ok, h2} = HooksQueries.get_by_repo_received_at(h1.repository_id, h1.received_at)

    assert h1 == h2
  end

  test "get_by_repo_received_at returns {:error, message} when hook with a given data does not exist" do
    id = UUID.uuid4()
    ts = DateTime.utc_now()
    assert {:error, message} = HooksQueries.get_by_repo_received_at(id, ts)
    assert message == "Hook from repo: #{id} received at: #{ts} not found."
  end

  # hooks_stuck_in_processing

  test "hooks_stuck_in_processing() properly filters hooks in DB based on given params", ctx do
    assert {:ok, h0} = insert(ctx, "bitbucket", "processing", :older_than_a_day)
    assert {:ok, h1} = insert(ctx, "bitbucket", "processing", :less_than_a_day_old)
    assert {:ok, h2} = insert(ctx, "bitbucket", "processing", :less_than_15s_old)
    assert {:ok, h3} = insert(ctx, "bitbucket", "processing", :less_than_15s_old)
    assert {:ok, _h4} = insert(ctx, "bitbucket", "launching", :older_than_a_day)
    assert {:ok, _h5} = insert(ctx, "bitbucket", "launching", :less_than_a_day_old)
    assert {:ok, _h6} = insert(ctx, "bitbucket", "launching", :less_than_15s_old)
    assert {:ok, _h7} = insert(ctx, "github", "processing", :older_than_a_day)
    assert {:ok, _h8} = insert(ctx, "github", "processing", :less_than_a_day_old)
    assert {:ok, _h9} = insert(ctx, "github", "processing", :less_than_15s_old)

    selected_fields = [:id, :project_id]

    assert {:ok, result} = HooksQueries.hooks_stuck_in_processing("bitbucket", 86_400_000, 200_000)

    assert [r1] = result
    assert take(r1, selected_fields) == take(h0, selected_fields)

    assert {:ok, result} = HooksQueries.hooks_stuck_in_processing("bitbucket", 15_000, 86_400)
    assert [r1] = result
    assert take(r1, selected_fields) == take(h1, selected_fields)

    assert {:ok, result} = HooksQueries.hooks_stuck_in_processing("bitbucket", 1_000, 15_400)
    assert [r1, r2] = result
    assert take(r1, selected_fields) == take(h3, selected_fields)
    assert take(r2, selected_fields) == take(h2, selected_fields)
  end

  defp take(struct, fields) do
    struct |> Map.from_struct() |> Map.take(fields)
  end

  defp insert(ctx, provider, state, timeframe) do
    payload = "#{provider}-#{state}-#{timeframe}"

    params = %{
      provider: provider,
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
  defp amount(:less_than_15s_old), do: -10
end
