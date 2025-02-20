defmodule Secrethub.Model.Checkout do
  @moduledoc """
  Schema model for checkout metadata
  """
  use Ecto.Schema

  @fields ~w(job_id pipeline_id workflow_id hook_id project_id user_id)a

  @primary_key false
  embedded_schema do
    field :job_id, :string
    field :pipeline_id, :string
    field :workflow_id, :string
    field :hook_id, :string
    field :project_id, :string
    field :user_id, :string
  end

  def from_params(params \\ %{}) do
    %__MODULE__{} |> changeset(params) |> Ecto.Changeset.apply_changes()
  end

  def changeset(checkout, params) do
    checkout
    |> Ecto.Changeset.cast(params, @fields)
  end
end
