defmodule RepositoryHub.Model.BuildStatusGuards do
  @moduledoc """
  One row per (repository_id, commit_sha, context, source_id) check: the last
  delivered commit-status state plus the in-flight delivery lease. Rows are
  ephemeral coordination state owned by `RepositoryHub.BuildStatusGuard`;
  nothing else reads or writes them.
  """

  use Ecto.Schema

  @primary_key false
  schema "build_status_guards" do
    field(:repository_id, Ecto.UUID, primary_key: true)
    field(:commit_sha, :string, primary_key: true)
    field(:context, :string, primary_key: true)
    field(:source_id, :string, primary_key: true)
    field(:last_state, :string)
    field(:claimed_at, :utc_datetime_usec)
    field(:updated_at, :utc_datetime_usec)
  end
end
