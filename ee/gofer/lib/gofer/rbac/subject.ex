defmodule Gofer.RBAC.Subject do
  @moduledoc """
  Encapsulates data for RBAC API
  """
  use Ecto.Schema

  embedded_schema do
    field(:organization_id, :string)
    field(:project_id, :string)
    field(:triggerer, :string)
  end
end
