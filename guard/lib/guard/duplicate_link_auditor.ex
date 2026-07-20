defmodule Guard.DuplicateLinkAuditor do
  @moduledoc """
  Periodically measures how many Git provider accounts are actively linked
  (revoked = false) to more than one user.

  Uniqueness is enforced at the application layer only, so pre-existing
  duplicates and rare write races are tolerated by design. This gauge is the
  compensating control: it shows whether that population shrinks over time
  and when a database unique index becomes feasible.
  """

  use Quantum, otp_app: :guard

  import Ecto.Query

  require Logger

  alias Guard.FrontRepo
  alias Guard.FrontRepo.RepoHostAccount

  @metric "guard.repo_host_account.active_duplicates"
  @enforced_hosts ~w(github bitbucket)

  @spec process() :: {:ok, %{String.t() => non_neg_integer()}}
  def process do
    Watchman.benchmark("guard.duplicate_link_auditor", fn ->
      duplicates = duplicate_counts()

      @enforced_hosts
      |> Enum.reduce(duplicates, fn host, acc -> Map.put_new(acc, host, 0) end)
      |> Enum.each(fn {host, count} ->
        Watchman.submit({@metric, [host]}, count)
      end)

      if duplicates != %{} do
        Logger.warning(
          "[DuplicateLinkAuditor] Active duplicate provider links detected: #{inspect(duplicates)}"
        )
      end

      {:ok, duplicates}
    end)
  end

  # Number of provider uids actively linked to more than one user, per host.
  defp duplicate_counts do
    from(r in RepoHostAccount,
      where: coalesce(r.revoked, false) == false,
      group_by: [r.repo_host, r.github_uid],
      having: count(r.id) > 1,
      select: r.repo_host
    )
    |> FrontRepo.all()
    |> Enum.frequencies()
  end
end
