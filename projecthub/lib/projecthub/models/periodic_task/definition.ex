defmodule Projecthub.Models.PeriodicTask.Definition do
  @moduledoc """
  Shared helpers for building `PeriodicDefinition` payloads sent to the
  periodic_scheduler `BulkUpsertAndPrune` RPC. Used by both
  `Projecthub.Models.PeriodicTask` (modern task path) and
  `Projecthub.Schedulers` (legacy scheduler path) so the branch->reference and
  status->state mappings stay in one place.
  """

  @spec format_branch_as_reference(String.t() | nil) :: String.t()
  def format_branch_as_reference("refs/tags/" <> _ = tag), do: tag
  def format_branch_as_reference("refs/pull/" <> _ = pr), do: pr

  def format_branch_as_reference(branch_name) when is_binary(branch_name) and branch_name != "",
    do: "refs/heads/#{branch_name}"

  def format_branch_as_reference(_), do: "refs/heads/main"

  @spec status_to_state(atom() | any()) :: :ACTIVE | :PAUSED | :UNCHANGED
  def status_to_state(:STATUS_ACTIVE), do: :ACTIVE
  def status_to_state(:STATUS_INACTIVE), do: :PAUSED
  def status_to_state(_), do: :UNCHANGED
end
