defmodule Deployment.Model.Deployment.ObjectRuleTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Gofer.Deployment.Model.Deployment.ObjectRule

  describe "changeset/2" do
    test "when type is absent then invalid" do
      invalid?(%{match_mode: :ALL}, type: "can't be blank")
    end

    test "when type is invalid then invalid" do
      invalid?(%{type: :UNKNOWN, match_mode: :ALL}, type: "is invalid")
    end

    test "when match_mode is absent then invalid" do
      invalid?(%{type: :BRANCH}, match_mode: "can't be blank")
    end

    test "when match_mode is invalid then invalid" do
      invalid?(%{type: :BRANCH, match_mode: :UNKNOWN}, match_mode: "is invalid")
    end

    test "when type = BRANCH and mode = ALL then valid" do
      valid?(%{type: :BRANCH, match_mode: :ALL})
    end

    test "when type = BRANCH, mode = EXACT, pattern is empty then invalid" do
      invalid?(%{type: :BRANCH, match_mode: :EXACT}, pattern: "can't be blank")
    end

    test "when type = BRANCH, mode = EXACT, pattern is not empty then invalid" do
      valid?(%{type: :BRANCH, match_mode: :EXACT, pattern: "master"})
    end

    test "when type = BRANCH, mode = REGEX, pattern is empty then invalid" do
      invalid?(%{type: :BRANCH, match_mode: :REGEX}, pattern: "can't be blank")
    end

    test "when type = BRANCH, mode = REGEX, pattern is invalid regex then invalid" do
      invalid?(%{type: :BRANCH, match_mode: :REGEX, pattern: "release/["},
        pattern: "must be regex"
      )
    end

    test "when type = BRANCH, mode = REGEX, pattern is valid regex then valid" do
      valid?(%{type: :BRANCH, match_mode: :REGEX, pattern: "release/.*"})
    end

    test "when type = TAG and mode = ALL then valid" do
      valid?(%{type: :TAG, match_mode: :ALL})
    end

    test "when type = TAG, mode = EXACT, pattern is empty then invalid" do
      invalid?(%{type: :TAG, match_mode: :EXACT}, pattern: "can't be blank")
    end

    test "when type = TAG, mode = EXACT, pattern is not empty then valid" do
      valid?(%{type: :TAG, match_mode: :EXACT, pattern: "latest"})
    end

    test "when type = TAG, mode = REGEX, pattern is empty then invalid" do
      invalid?(%{type: :TAG, match_mode: :REGEX}, pattern: "can't be blank")
    end

    test "when type = TAG, mode = REGEX, pattern is invalid regex then invalid" do
      invalid?(%{type: :TAG, match_mode: :REGEX, pattern: "v1./["},
        pattern: "must be regex"
      )
    end

    test "when type = TAG, mode = REGEX, pattern is valid regex then valid" do
      valid?(%{type: :TAG, match_mode: :REGEX, pattern: "v1\.0\.[0-9]+"})
    end

    test "when type = PR and mode = ALL then valid" do
      valid?(%{type: :PR, match_mode: :ALL})
    end

    test "when type = PR, mode = EXACT, pattern is empty then invalid" do
      invalid?(%{type: :PR, match_mode: :EXACT}, pattern: "can't be blank")
    end

    test "when type = PR, mode = EXACT, pattern is not empty then valid" do
      valid?(%{type: :PR, match_mode: :EXACT, pattern: "latest"})
    end

    test "when type = PR, mode = REGEX, pattern is empty then invalid" do
      invalid?(%{type: :PR, match_mode: :REGEX}, pattern: "can't be blank")
    end

    test "when type = PR, mode = REGEX, pattern is invalid regex then invalid" do
      invalid?(%{type: :PR, match_mode: :REGEX, pattern: "v1./["},
        pattern: "must be regex"
      )
    end

    test "when type = PR, mode = REGEX, pattern is valid regex then valid" do
      valid?(%{type: :PR, match_mode: :REGEX, pattern: "v1\.0\.[0-9]+"})
    end
  end

  defp valid?(params) do
    assert %Ecto.Changeset{valid?: true} = ObjectRule.changeset(%ObjectRule{}, params)
  end

  defp invalid?(params, expected_errors) do
    assert %Ecto.Changeset{valid?: false, errors: errors} =
             ObjectRule.changeset(%ObjectRule{}, params)

    assert ^expected_errors =
             Enum.map(errors, fn {field, {message, _extra}} -> {field, message} end)
  end
end
