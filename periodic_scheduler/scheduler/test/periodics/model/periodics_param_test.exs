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

    test "with validate_input_format and valid regex_pattern is valid" do
      changeset =
        assert_valid(%{
          name: "VERSION",
          required: true,
          validate_input_format: true,
          regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$",
          default_value: "1.2.3"
        })

      assert %PeriodicsParam{
               validate_input_format: true,
               regex_pattern: "^[0-9]+\\.[0-9]+\\.[0-9]+$"
             } = Ecto.Changeset.apply_changes(changeset)
    end

    test "with validate_input_format and blank regex_pattern is invalid" do
      assert [regex_pattern: {msg, _}] =
               assert_invalid(%{
                 name: "VERSION",
                 required: true,
                 validate_input_format: true,
                 regex_pattern: ""
               })

      assert msg =~ "can't be blank"
    end

    test "with validate_input_format and invalid regex_pattern is invalid" do
      assert [regex_pattern: {msg, _}] =
               assert_invalid(%{
                 name: "VERSION",
                 required: true,
                 validate_input_format: true,
                 regex_pattern: "["
               })

      assert msg =~ "not a valid regex"
    end

    test "with validate_input_format and default_value not matching regex is invalid" do
      assert [default_value: {msg, _}] =
               assert_invalid(%{
                 name: "VERSION",
                 required: true,
                 validate_input_format: true,
                 regex_pattern: "^[0-9]+$",
                 default_value: "abc"
               })

      assert msg =~ "does not match"
    end

    test "with regex_pattern over the length cap is invalid" do
      pattern = String.duplicate("a", Util.SafeRegex.max_pattern_length() + 1)

      assert [regex_pattern: {msg, _}] =
               assert_invalid(%{
                 name: "VERSION",
                 required: true,
                 validate_input_format: true,
                 regex_pattern: pattern
               })

      assert msg =~ "too long"
    end

    test "with validate_input_format false, oversized regex_pattern is normalized to nil" do
      pattern = String.duplicate("a", Util.SafeRegex.max_pattern_length() + 1)

      changeset =
        assert_valid(%{
          name: "VERSION",
          required: true,
          validate_input_format: false,
          regex_pattern: pattern
        })

      assert %PeriodicsParam{regex_pattern: nil, validate_input_format: false} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "with validate_input_format false, valid regex_pattern is normalized to nil" do
      changeset =
        assert_valid(%{
          name: "VERSION",
          required: true,
          validate_input_format: false,
          regex_pattern: "^[0-9]+$"
        })

      assert %PeriodicsParam{regex_pattern: nil, validate_input_format: false} =
               Ecto.Changeset.apply_changes(changeset)
    end

    test "without validate_input_format ignores regex_pattern checks and clears the pattern" do
      changeset =
        assert_valid(%{
          name: "VERSION",
          required: true,
          validate_input_format: false,
          regex_pattern: "[",
          default_value: "anything"
        })

      assert %PeriodicsParam{regex_pattern: nil} = Ecto.Changeset.apply_changes(changeset)
    end

    test "with invalid regex_pattern and a default_value reports only the regex_pattern error" do
      assert [regex_pattern: {msg, _}] =
               assert_invalid(%{
                 name: "VERSION",
                 required: true,
                 validate_input_format: true,
                 regex_pattern: "[",
                 default_value: "x"
               })

      assert msg =~ "not a valid regex"
    end

    test "with regex_pattern over the length cap and a default_value reports only the regex_pattern error" do
      pattern = String.duplicate("a", Util.SafeRegex.max_pattern_length() + 1)

      assert [regex_pattern: {msg, _}] =
               assert_invalid(%{
                 name: "VERSION",
                 required: true,
                 validate_input_format: true,
                 regex_pattern: pattern,
                 default_value: "x"
               })

      assert msg =~ "too long"
    end

    test "default_value mismatch still surfaces when regex_pattern is valid" do
      assert [default_value: {msg, _}] =
               assert_invalid(%{
                 name: "VERSION",
                 required: true,
                 validate_input_format: true,
                 regex_pattern: "^[0-9]+$",
                 default_value: "abc"
               })

      assert msg =~ "does not match"
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
