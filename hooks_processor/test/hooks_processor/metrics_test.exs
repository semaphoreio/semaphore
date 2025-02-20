defmodule MetricsTest do
  use ExUnit.Case, async: false

  alias HooksProcessor.Metrics
  alias HooksProcessor.Hooks.Model.HooksQueries

  setup_all do
    Application.stop(:watchman)

    Test.Helpers.wait_until_stopped(:watchman)

    on_exit(fn ->
      Test.Helpers.ensure_unregistered(Watchman.Server)
      Application.ensure_all_started(:watchman)
    end)
  end

  setup do
    Test.Helpers.ensure_unregistered(Watchman.Server)

    Process.register(self(), Watchman.Server)
    Test.Helpers.truncate_db()

    :ok
  end

  test "it can start" do
    children = [Metrics]

    opts = [strategy: :one_for_one]
    assert {:ok, pid} = Supervisor.start_link(children, opts)

    Process.unlink(pid)
    Process.exit(pid, :kill)
  end

  describe "measuring stuck hooks" do
    test "when there are no stuck hooks" do
      assert {:ok, _} = create_hook(%{state: "launching"})

      Metrics.measure()

      assert_received {:"$gen_cast",
                       {:send,
                        [
                          internal: {"hooks.processing.stuck.count", ["total"]},
                          external: {"IncomingHooks.processing", [state: "stuck"]}
                        ], 0, :gauge}}
    end

    test "when there are several stuck hooks" do
      assert {:ok, _} = create_hook(%{inserted_at: ago(10, :mins)})
      assert {:ok, _} = create_hook(%{inserted_at: ago(3, :hours)})

      Metrics.measure()

      assert_received {:"$gen_cast",
                       {:send,
                        [
                          internal: {"hooks.processing.stuck.count", ["total"]},
                          external: {"IncomingHooks.processing", [state: "stuck"]}
                        ], 2, :gauge}}
    end

    test "when there are several stuck hooks but are over the deadline" do
      assert {:ok, _} = create_hook(%{inserted_at: ago(10, :days)})
      assert {:ok, _} = create_hook(%{inserted_at: ago(3, :days)})

      Metrics.measure()

      assert_received {:"$gen_cast",
                       {:send,
                        [
                          internal: {"hooks.processing.stuck.count", ["total"]},
                          external: {"IncomingHooks.processing", [state: "stuck"]}
                        ], 0, :gauge}}
    end
  end

  defp create_hook(params) do
    defaults = %{
      project_id: UUID.uuid4(),
      organization_id: UUID.uuid4(),
      provider: "github",
      repository_id: UUID.uuid4(),
      received_at: DateTime.utc_now(),
      inserted_at: DateTime.utc_now(),
      webhook: %{"id" => "lol"},
      state: "processing"
    }

    params = Map.merge(defaults, params)

    HooksQueries.insert(params)
  end

  defp now, do: DateTime.utc_now()

  defp ago(n, :secs), do: DateTime.add(now(), -n, :second)
  defp ago(n, :mins), do: ago(n * 60, :secs)
  defp ago(n, :hours), do: ago(n * 60, :mins)
  defp ago(n, :days), do: ago(n * 24, :hours)
end
