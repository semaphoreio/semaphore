defmodule Scheduler.Periodics.Model.PeriodicsParamTest do
  use ExUnit.Case, async: true
  alias Scheduler.Periodics.Model.PeriodicsParam

  describe "changeset/2" do
    test "with all fields is valid" do
      changeset =
        assert_valid(%{
          name: "parameter_name",
          description: "parameter description",
          required: true,
          options: ["opt_1", "opt_2"],
          default_value: "opt_1"
        })

      assert %PeriodicsParam{
               name: "parameter_name",
               description: "parameter description",
               required: true,
               options: ["opt_1", "opt_2"],
               default_value: "opt_1"
             } = Ecto.Changeset.apply_changes(changeset)
    end

    test "without name is invalid" do
      assert [name: {"can't be blank", _}] =
               assert_invalid(%{
                 description: "parameter description",
                 required: true,
                 options: ["opt_1", "opt_2"],
                 default_value: "opt_1"
               })
    end

    test "without description is valid" do
      assert assert_valid(%{
               name: "parameter_name",
               required: true,
               options: ["opt_1", "opt_2"]
             })
    end

    test "with required set to true and with default_value is valid" do
      assert_valid(%{
        name: "parameter_name",
        required: true,
        options: ["opt_1", "opt_2"],
        default_value: "opt_1"
      })
    end

    test "with required set to true and without default_value is valid" do
      assert_valid(%{
        name: "parameter_name",
        required: true,
        options: ["opt_1", "opt_2"]
      })
    end

    test "without options is valid" do
      assert_valid(%{
        name: "parameter_name",
        required: false
      })
    end
  end

  defp assert_valid(params) do
    assert changeset = PeriodicsParam.changeset(%PeriodicsParam{}, params)
    assert %Ecto.Changeset{valid?: true, errors: []} = changeset

    changeset
  end

  defp assert_invalid(params) do
    assert %Ecto.Changeset{valid?: false, errors: errors} =
             PeriodicsParam.changeset(%PeriodicsParam{}, params)

    errors
  end
end
