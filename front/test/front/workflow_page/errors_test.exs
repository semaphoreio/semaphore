defmodule Front.WorkflowPage.ErrorsTest do
  use FrontWeb.ConnCase

  describe ".has_errors?" do
    test "if nil return false" do
      refute Front.WorkflowPage.Errors.has_errors?(%{error_description: nil})
    end

    test "if empty string return false" do
      refute Front.WorkflowPage.Errors.has_errors?(%{error_description: ""})
    end

    test "if not a string return false" do
      refute Front.WorkflowPage.Errors.has_errors?(%{error_description: 12})
    end

    test "if non-empty string return true" do
      assert Front.WorkflowPage.Errors.has_errors?(%{error_description: "error while parsing"})
    end
  end

  describe ".tabs_used_for_indentation?" do
    test "it return true if the error has the characteristics of a tab indent error" do
      error = """
      Error: {{:throw, {:yamerl_exception, [{:yamerl_parsing_error, :error,
      'Block mapping value not allowed here', 12, 9,
      :block_mapping_value_not_allowed, :undefined, []}]}},
      "version: v1.0\n\\tname: Complex pipeline without dependencies\nagent:\n
      """

      assert Front.WorkflowPage.Errors.tabs_used_for_indentation?(error)
    end

    test "it returns false for other errot types" do
      error = "some other error"

      refute Front.WorkflowPage.Errors.tabs_used_for_indentation?(error)
    end
  end

  describe ".is_structured_error?" do
    test "if it is parsable, return true" do
      err = """
        {
          "location":{
            "file":".semaphore/semaphore.yml",
            "path":["blocks","0","run","when"]
          },
          "message":"Invalid expression on the left of 'or' operator.",
          "type":"ErrorInvalidWhenExpression"
        }
      """

      assert Front.WorkflowPage.Errors.is_structured_error?(err)
    end

    test "if it is not parsable, return false" do
      err = """
      Error: {{:throw, {:yamerl_exception, [{:yamerl_parsing_error, :error,
      'Block mapping value not allowed here', 12, 9,
      :block_mapping_value_not_allowed, :undefined, []}]}},
      "version: v1.0\n\\tname: Complex pipeline without dependencies\nagent:\n
      """

      refute Front.WorkflowPage.Errors.is_structured_error?(err)
    end
  end
end
