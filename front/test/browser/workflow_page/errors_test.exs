defmodule Front.Browser.WorkflowPage.ErrorTest do
  use FrontWeb.WallabyCase

  setup data do
    stubs = Support.Browser.WorkflowPage.create_workflow()
    context = Map.merge(data, stubs)

    Support.Stubs.PermissionPatrol.allow_everything()

    task = Support.Stubs.Pipeline.add_compile_task(context.pipeline.id)
    Support.Stubs.Task.change_state(task, :finished, :failed)
    Support.Stubs.Pipeline.change_state(context.pipeline.id, :failed)

    {:ok, context}
  end

  browser_test "generic structured error", context do
    err = """
      {
        "message": "Initialization step failed, see logs for more details.",
        "location":{
          "file": ".semaphore/semaphore.yml",
          "path": []
        },
        "type":"ErrorInitializationFailed"
      }
    """

    Support.Stubs.Pipeline.set_error(context.pipeline.id, err)

    page = open(context)

    assert has_text?(page, "We couldn't run your pipeline")
    assert has_text?(page, "Initialization failed. See logs for more details.")
  end

  browser_test "when language error", context do
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

    Support.Stubs.Pipeline.set_error(context.pipeline.id, err)

    page = open(context)

    assert has_text?(page, "We couldn't run your pipeline")
    assert has_text?(page, "Invalid when expression detected")
    assert has_text?(page, "Invalid expression on the left of")
  end

  browser_test "missing branch in change_in expression", context do
    err = """
      {
        "type": "ErrorChangeInMissingBranch",
        "message": "Unknown git reference 'master'.",
        "location": {
          "file": ".semaphore/semaphore.yml",
          "path": ["blocks", "0", "skip", "when"]
        }
      }
    """

    Support.Stubs.Pipeline.set_error(context.pipeline.id, err)

    page = open(context)

    assert has_text?(page, "We couldn't run your pipeline")
    assert has_text?(page, "Unknown branch referenced")
    assert has_text?(page, "Error: Unknown git reference 'master'.")

    msg = "By default, change_in compares your changes to the HEAD of the master branch."
    assert has_text?(page, msg)

    msg = "change_in([paths...], {default_branch: 'main'}"
    assert has_text?(page, msg)
  end

  browser_test "pipeline YAML has tabs", context do
    err = """
      Error: {{:throw, {:yamerl_exception, [{:yamerl_parsing_error, :error,
      'Block mapping value not allowed here', 12, 9,
      :block_mapping_value_not_allowed, :undefined, []}]}},
      "version: v1.0\n\\tname: Complex pipeline without dependencies\nagent:\n
    """

    Support.Stubs.Pipeline.set_error(context.pipeline.id, err)

    page = open(context)

    assert has_text?(page, "We couldn't run your pipeline")
    assert has_text?(page, "Unprocessable YAML file.")
  end

  browser_test "unknown error", context do
    err = """
      Error: {{:throw, {:, [{:, :error,
      'Block mapping value not allowed here', 12, 9,}}}}
    """

    Support.Stubs.Pipeline.set_error(context.pipeline.id, err)

    page = open(context)

    assert has_text?(page, "We couldn't run your pipeline")
    assert has_text?(page, "Error")
    assert has_text?(page, "Block mapping")
  end

  defp open(params) do
    path = "/workflows/#{params.workflow.id}?pipeline_id=#{params.pipeline.id}"

    params.session |> visit(path)
  end
end
