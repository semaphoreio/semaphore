defmodule Secrethub.Model.File do
  @moduledoc """
  Schema model for secret file
  """
  use Ecto.Schema

  @primary_key false
  embedded_schema do
    field :path, :string
    field :content, :string
  end

  def changeset(file, params) do
    file
    |> Ecto.Changeset.cast(params, [:path, :content])
    |> Ecto.Changeset.validate_required([:path, :content])
  end
end
