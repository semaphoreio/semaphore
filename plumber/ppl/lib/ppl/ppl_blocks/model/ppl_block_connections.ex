defmodule Ppl.PplBlocks.Model.PplBlockConnections do
  @moduledoc """
  Models inter-ppl_block dependencies

  Each ppl_block contains informationabout about its dependencies:
  which ppl_blocks must finish execution before this ppl_block
  can start running.
  """

  alias Ppl.PplBlocks.Model.PplBlocks

  use Ecto.Schema

  import Ecto.Changeset

  schema "pipeline_block_connections" do

    belongs_to :target_pipeline_block, PplBlocks, [foreign_key: :target]
    belongs_to :dependency_pipeline_block, PplBlocks, [foreign_key: :dependency]
  end

  @required_fields ~w(target dependency)a
  @optional_fields ~w()a

  def changeset(pipeline_block_dependency, params \\ %{}) do
    pipeline_block_dependency
    |> cast(params, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint(:target_dependency)
    |> foreign_key_constraint(:target)
    |> foreign_key_constraint(:dependency)
  end
end
