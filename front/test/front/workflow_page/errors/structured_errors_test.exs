defmodule Front.WorkflowPage.Errors.StructuredErrorTest do
  use FrontWeb.ConnCase

  alias Front.WorkflowPage.Errors.StructuredError

  describe ".parsable?" do
    test "if it is parsable, return true" do
      err = invalid_when_err()

      assert StructuredError.parsable?(err)
    end

    test "if it is not parsable, return false" do
      err = non_parsable_err()

      refute StructuredError.parsable?(err)
    end
  end

  describe ".parse" do
    test "if it is parsable, return ok tuple" do
      err = invalid_when_err()

      assert {:ok, parsed} = StructuredError.parse(err)
      assert parsed["location"]["file"] == ".semaphore/semaphore.yml"
    end

    test "if it is not parsable, return error tuple" do
      err = non_parsable_err()

      assert {:error, _} = StructuredError.parse(err)
    end
  end

  describe ".invalid_when?" do
    test "when type is ErrorInvalidWhenExpression => returns true" do
      err = invalid_when_err()

      assert {:ok, parsed} = StructuredError.parse(err)
      assert StructuredError.invalid_when?(parsed)
    end

    test "when type is ErrorInvalidWhenExpression => returns false" do
      err = invalid_branch_err()

      assert {:ok, parsed} = StructuredError.parse(err)
      refute StructuredError.invalid_when?(parsed)
    end
  end

  describe ".path" do
    test "constructs a nice path to the problem" do
      err = invalid_when_err()

      assert {:ok, parsed} = StructuredError.parse(err)
      assert StructuredError.path(parsed) == "blocks[0] / run / when"
    end
  end

  defp invalid_when_err do
    """
      {
        "location":{
          "file":".semaphore/semaphore.yml",
          "path":["blocks","0","run","when"]
        },
        "message":"Invalid expression on the left of 'or' operator.",
        "type":"ErrorInvalidWhenExpression"
      }
    """
  end

  defp invalid_branch_err do
    """
      {
        "location":{
          "file":".semaphore/semaphore.yml",
          "path":["blocks","0","run","when"]
        },
        "message":"Invalid expression on the left of 'or' operator.",
        "type":"ErrorInvalidBranch"
      }
    """
  end

  defp non_parsable_err do
    """
     Error: {{:throw, {:yamerl_exception, [{:yamerl_parsing_error, :error,
     'Block mapping value not allowed here', 12, 9,
     :block_mapping_value_not_allowed, :undefined, []}]}},
     "version: v1.0\n\\tname: Complex pipeline without dependencies\nagent:\n
    """
  end
end
