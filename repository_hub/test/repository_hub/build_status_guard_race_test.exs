defmodule RepositoryHub.BuildStatusGuardRaceTest do
  # Claim racing needs real committed transactions across independent
  # connections, which the shared sandbox cannot provide — this module runs
  # the pool in auto mode and cleans up after itself.
  use ExUnit.Case, async: false

  alias RepositoryHub.{BuildStatusGuard, InternalApiFactory, Repo}

  setup do
    Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)

    request =
      InternalApiFactory.create_build_status_request(
        repository_id: Ecto.UUID.generate(),
        context: "ci/semaphoreci/push: Pipeline",
        source_id: Ecto.UUID.generate(),
        status: :PENDING
      )

    on_exit(fn ->
      Ecto.Adapters.SQL.Sandbox.mode(Repo, :auto)

      Repo.query!("DELETE FROM build_status_guards WHERE source_id = $1", [request.source_id])

      Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)
    end)

    %{request: request}
  end

  test "exactly one concurrent claimant wins the lease", %{request: request} do
    results =
      1..8
      |> Enum.map(fn _ -> Task.async(fn -> BuildStatusGuard.claim(request) end) end)
      |> Task.await_many(15_000)

    assert Enum.count(results, &match?({:ok, _}, &1)) == 1
    assert Enum.count(results, &(&1 == :busy)) == 7
  end
end
