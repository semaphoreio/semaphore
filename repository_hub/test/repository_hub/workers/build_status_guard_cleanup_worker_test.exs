defmodule RepositoryHub.BuildStatusGuardCleanupWorkerTest do
  use RepositoryHub.Case, async: false

  alias RepositoryHub.{BuildStatusGuardCleanupWorker, Repo}

  # One over the batch size, so a full drain needs more than one delete.
  @expired_rows 5_001

  test "one tick drains all expired rows without re-sending :tick to itself" do
    pid = start_supervised!(BuildStatusGuardCleanupWorker)
    Ecto.Adapters.SQL.Sandbox.allow(Repo, self(), pid)

    seed_rows(@expired_rows, "9 days")
    seed_rows(1, "1 hour")

    :erlang.trace(pid, true, [:receive])

    send(pid, :tick)
    :sys.get_state(pid)

    assert row_count("9 days ago batch") == 0
    assert row_count("1 hour ago batch") == 1

    # The drain must happen inside one tick — a worker that re-sends :tick to
    # itself schedules a permanent extra hourly timer per drained batch.
    assert_received {:trace, ^pid, :receive, :tick}
    refute_received {:trace, ^pid, :receive, :tick}
  end

  defp seed_rows(count, age) do
    Repo.query!(
      """
      INSERT INTO build_status_guards
        (repository_id, commit_sha, context, source_id, updated_at)
      SELECT md5('#{age}' || i::text)::uuid, 'sha', '#{age} ago batch', i::text,
             now() - interval '#{age}'
      FROM generate_series(1, #{count}) AS i
      """,
      [],
      timeout: 30_000
    )
  end

  defp row_count(context) do
    %{rows: [[count]]} =
      Repo.query!("SELECT count(*) FROM build_status_guards WHERE context = $1", [context])

    count
  end
end
