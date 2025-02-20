defmodule Ppl.LatestWfs.Model.LatestWfs do
  @moduledoc """
  LatestWfs type

  Stores data about latest workflow per git ref for each project
  """

  use Ecto.Schema

  import Ecto.Changeset

  schema "latest_workflows" do
    field :organization_id, :string
    field :project_id, :string

    # e.g. master, v1.0 or 123
    field :git_ref, :string

    # values: branch, tag or pr
    field :git_ref_type, :string

    field :wf_id, :string
    field :wf_number, :integer

    timestamps(type: :naive_datetime_usec)
  end

  @required_fields ~w(organization_id project_id git_ref git_ref_type
                      wf_id wf_number)a
  @valid_git_ref_types ~w(branch tag pr)


  def changeset(latest_wf, params \\ %{}) do
    latest_wf
    |> cast(params, @required_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:git_ref_type, @valid_git_ref_types)
    # this unique_constraint references unique_index in migration
    |> unique_constraint(:one_wf_per_git_ref_on_project, name: :one_wf_per_git_ref_on_project)
  end
end
