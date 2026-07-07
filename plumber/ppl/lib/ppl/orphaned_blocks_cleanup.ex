defmodule Ppl.OrphanedBlocksCleanup do
  @moduledoc """
  One-off maintenance task that cancels pipeline blocks orphaned in a
  non-terminal state while the pipeline they belong to had already transitioned
  to 'done'.

  It is meant to be run once, explicitly, from a dedicated one-off Kubernetes Job
  (NOT as part of pod startup):

      bin/ppl eval "Ppl.OrphanedBlocksCleanup.run()"

  Set DRY_RUN=true to only report how many blocks would be affected without
  changing anything:

      DRY_RUN=true bin/ppl eval "Ppl.OrphanedBlocksCleanup.run()"

  The actual work is a single, side-effect-free DB update (see
  `Ppl.PplBlocks.Model.PplBlocksQueries.cancel_orphaned_blocks/1`): it does not go
  through the state machine, so no events, epilogues or promotions are triggered
  and the results of the (already finished) pipelines are left intact. It is
  idempotent and safe to re-run.
  """

  @start_apps [:crypto, :ssl, :postgrex, :ecto]

  alias Ppl.PplBlocks.Model.PplBlocksQueries

  def run() do
    Enum.each(@start_apps, &Application.ensure_all_started/1)
    {:ok, _} = Ppl.EctoRepo.start_link(pool_size: 2)

    dry_run? = dry_run?()
    {:ok, count} = PplBlocksQueries.cancel_orphaned_blocks(dry_run?)

    if dry_run? do
      IO.puts("[orphaned_blocks_cleanup] DRY RUN: #{count} orphaned block(s) would be canceled.")
    else
      IO.puts("[orphaned_blocks_cleanup] Canceled #{count} orphaned block(s).")
    end

    :init.stop()
  end

  defp dry_run? do
    value = System.get_env("DRY_RUN", "false") |> String.downcase()
    value in ["true", "1", "yes"]
  end
end
