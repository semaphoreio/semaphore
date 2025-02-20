defmodule ToolkitTest do
  use ExUnit.Case, async: true
  doctest Toolkit, import: true
  alias Toolkit

  describe "consolidate_changeset_errors" do
    test "transforms changeset errors to a more readable form" do
      data = %{}
      types = %{name: :string, email: :string}
      params = %{name: 1}

      changeset =
        {data, types}
        |> Ecto.Changeset.cast(params, Map.keys(types))
        |> Ecto.Changeset.validate_required([:name, :email])

      assert changeset.valid? == false

      assert Toolkit.consolidate_changeset_errors(changeset) ==
               "email can't be blank, name is invalid"
    end
  end
end
