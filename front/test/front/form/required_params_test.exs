defmodule Front.Form.RequiredParamsTest do
  use ExUnit.Case
  alias Front.Form.RequiredParams, as: Subject

  defmodule ParamsToValidate do
    use Ecto.Schema

    embedded_schema do
      field(:name, :string)
      field(:branch, :string)
    end

    def required_fields, do: [:name]
  end

  describe ".create_changeset" do
    test "when required field is not provided, it creates an invalid changeset with the field error" do
      input_params = %{
        branch: nil,
        name: nil
      }

      changeset =
        Subject.create_changeset(
          input_params,
          ParamsToValidate.required_fields(),
          %ParamsToValidate{}
        )

      assert not changeset.valid?
      assert changeset.errors == [name: "Required. Cannot be empty."]
    end

    test "when required field is provided, it creates changeset in expected form" do
      input_params = %{
        branch: nil,
        name: "just-a-test"
      }

      assert Subject.create_changeset(
               input_params,
               ParamsToValidate.required_fields(),
               %ParamsToValidate{}
             ) == %{changes: %{name: "just-a-test"}, errors: [], valid?: true}
    end
  end
end
