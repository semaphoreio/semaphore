defmodule HooksProcessor.Hooks.Model.Hooks do
  @moduledoc """
  Represents a webhook entity stored in the workflows table of front DB
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @timestamps_opts [type: :naive_datetime_usec]
  schema "workflows" do
    field(:project_id, :binary_id)
    field(:request, :map)
    field(:ppl_id, :binary_id)
    field(:result, :string)
    field(:branch_id, :binary_id)
    field(:commit_sha, :string)
    field(:git_ref, :string)
    field(:state, :string)
    field(:commit_author, :string)
    # new fields
    field(:provider, :string)
    field(:repository_id, :binary_id)
    field(:received_at, :utc_datetime_usec)
    field(:wf_id, :binary_id)
    field(:organization_id, :binary_id)

    timestamps(inserted_at_source: :created_at)
  end

  @required_fields ~w(project_id request state provider repository_id received_at
                      organization_id)a
  @optional_fields ~w(wf_id ppl_id result branch_id commit_sha git_ref inserted_at
                      commit_author)a
  @valid_states ~w(no_project pr_approval skip_ci deleting_branch skip_pr
                   skip_forked_pr filtered_contributor skip_tag whitelist_tag
                   skip_branch whitelist_branch pr_non_mergeable launching
                   unauthorized_repo not_found_repo processing failed)
  @base_providers ~w(github bitbucket gitlab api git)

  def changeset(hook, params \\ %{}) do
    hook
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:state, @valid_states)
    |> validate_inclusion(:provider, valid_providers())
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_hook_received_at_per_repository,
      name: :one_hook_received_at_per_repository
    )
  end

  defp valid_providers do
    if Application.get_env(:hooks_processor, :environment) == :test do
      @base_providers ++ ["test"]
    else
      @base_providers
    end
  end
end
