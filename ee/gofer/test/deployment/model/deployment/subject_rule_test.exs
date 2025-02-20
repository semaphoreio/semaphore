defmodule Deployment.Model.Deployment.SubjectRuleTest do
  @moduledoc false
  use ExUnit.Case, async: true
  alias Gofer.Deployment.Model.Deployment.SubjectRule

  describe "changeset/2" do
    test "when type is absent then invalid" do
      invalid?(%{subject_id: UUID.uuid4()}, type: "can't be blank")
    end

    test "when type is invalid then invalid" do
      invalid?(%{type: :UNKNOWN, subject_id: UUID.uuid4()}, type: "is invalid")
    end

    test "when type is USER, ROLE or GROUP and subject_id is missing then invalid" do
      invalid?(%{type: :USER}, subject_id: "can't be blank")
      invalid?(%{type: :ROLE}, subject_id: "can't be blank")
      invalid?(%{type: :GROUP}, subject_id: "can't be blank")
    end

    test "when type is valid and subject_id is present then valid" do
      valid?(%{type: :ROLE, subject_id: UUID.uuid4()})
      valid?(%{type: :USER, subject_id: UUID.uuid4()})
      valid?(%{type: :GROUP, subject_id: UUID.uuid4()})
    end

    test "when type is ANY or AUTO then valid" do
      valid?(%{type: :ANY})
      valid?(%{type: :AUTO})
      valid?(%{type: :ANY, subject_id: UUID.uuid4()})
      valid?(%{type: :AUTO, subject_id: UUID.uuid4()})
    end
  end

  defp valid?(params) do
    assert %Ecto.Changeset{valid?: true} = SubjectRule.changeset(%SubjectRule{}, params)
  end

  defp invalid?(params, expected_errors) do
    assert %Ecto.Changeset{valid?: false, errors: errors} =
             SubjectRule.changeset(%SubjectRule{}, params)

    assert ^expected_errors =
             Enum.map(errors, fn {field, {message, _extra}} -> {field, message} end)
  end
end
