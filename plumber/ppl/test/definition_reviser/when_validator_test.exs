defmodule Ppl.DefinitionReviser.WhenValidator.Test do
  use Ppl.IntegrationCase

  alias Ppl.Actions

  @grpc_port 50073
  setup_all do
    Test.Support.GrpcServerHelper.start_server_with_cleanup(Test.MockGoferService)
  end

  setup %{port: port} do
    Test.Support.GrpcServerHelper.setup_service_url("INTERNAL_API_URL_GOFER", port)
    Test.Helpers.truncate_db()
    {:ok, %{}}
  end

  @tag :integration
  test "pipeline with valid expressions in all when conditions passes" do
    test_gofer_service_response("valid")

    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "multiple_valid_whens.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 15_000)

    assert ppl.result == "passed"

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "pipeline with invalid expression in one of when conditions finishes as malformed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "invalid_when_cond.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 15_000)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    message = "Invalid 'when' condition on path '#/blocks/1/skip/when': "
              <> "Syntax error on line 1. - Invalid expression on the left of '=' operator."
    assert String.contains?(ppl.error_description, message)

    Test.Helpers.stop_all_loopers(loopers)
  end

  @tag :integration
  test "pipeline with when condition that uses result or result_reason outside of promotion conditions finishes as malformed" do
    {:ok, %{ppl_id: ppl_id}} =
      %{"repo_name" => "22_skip_block", "file_name" => "invalid_use_result_in_block_when_cond.yml"}
      |> Test.Helpers.schedule_request_factory(:local)
      |> Actions.schedule()

    loopers = Test.Helpers.start_all_loopers()

    {:ok, ppl} = Test.Helpers.wait_for_ppl_state(ppl_id, "done", 15_000)

    assert ppl.result == "failed"
    assert ppl.result_reason == "malformed"
    message = "Invalid 'when' condition on path '#/blocks/1/skip/when': "
              <> "Missing value of keyword parameter 'result'."
    assert String.contains?(ppl.error_description, message)

    Test.Helpers.stop_all_loopers(loopers)
  end

  defp test_gofer_service_response(value),
    do: Application.put_env(:gofer_client, :test_gofer_service_response, value)
end
