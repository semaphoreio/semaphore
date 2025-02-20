defmodule GoferClient.ResponseParser.Test do
  use ExUnit.Case

  alias InternalApi.Gofer.ResponseStatus.ResponseCode
  alias InternalApi.Gofer.{ResponseStatus, CreateResponse, PipelineDoneResponse}
  alias GoferClient.ResponseParser

  # Create

  test "{:ok, OK_response} from create is parsed into {:ok, switch_id}" do
    id = UUID.uuid4()
    status = %ResponseStatus{message: "", code: code(:OK)}
    response = %CreateResponse{switch_id: id, response_status: status}

    assert {:ok, result} =  ResponseParser.process_create_response({:ok, response})
    assert result == id
  end

  test "{:ok, BAD_PARAM_response} from create is parsed into {:error, gofer_message}" do
    status = %ResponseStatus{message: "Error message", code: code(:BAD_PARAM)}
    response = %CreateResponse{switch_id: "", response_status: status}

    assert {:error, result} =  ResponseParser.process_create_response({:ok, response})
    assert result == "Error message"
  end

  test "{:ok, MALFORMED_response} from create is parsed into {:error, {:malformed, gofer_message}}" do
    status = %ResponseStatus{message: "Error message", code: code(:MALFORMED)}
    response = %CreateResponse{switch_id: "", response_status: status}

    assert {:error, result} =  ResponseParser.process_create_response({:ok, response})
    assert result == {:malformed, "Error message"}
  end

  test '{:ok, :switch_not_defined} from create is parsed into {:ok, ""}' do
    assert {:ok, ""} = ResponseParser.process_create_response({:ok, :switch_not_defined})
  end

  test "{:ok, invalid_data} from create is parsed into {:error, invalid_data}" do
    assert {:error, []} = ResponseParser.process_create_response({:ok, []})
  end

  test "everything that is not an ok_tuple from create is returned as is" do
    assert {:error, "Error desc"} = ResponseParser.process_create_response({:error, "Error desc"})
  end

  # PipelineDone

  test "{:ok, OK_response} from pipeline_done is parsed into {:ok, message}" do
    status = %ResponseStatus{message: "Valid message", code: code(:OK)}
    response = %PipelineDoneResponse{response_status: status}

    assert {:ok, result} = ResponseParser.process_pipeline_done_response({:ok, response})
    assert result == "Valid message"
  end

  test "{:ok, BAD_PARAM_response} from pipeline_done is parsed into {:error, gofer_message}" do
    status = %ResponseStatus{message: "Error message", code: code(:BAD_PARAM)}
    response = %PipelineDoneResponse{response_status: status}

    assert {:error, result} =  ResponseParser.process_pipeline_done_response({:ok, response})
    assert result == "Error message"
  end

  test "{:ok, RESULT_CHANGED_response} from pipeline_done is parsed into {:error, gofer_message}" do
    status = %ResponseStatus{message: "Result changed", code: code(:RESULT_CHANGED)}
    response = %PipelineDoneResponse{response_status: status}

    assert {:error, result} =  ResponseParser.process_pipeline_done_response({:ok, response})
    assert result == "Result changed"
  end

  test "{:ok, RESULT_REASON_CHANGED_response} from pipeline_done is parsed into {:error, gofer_message}" do
    status = %ResponseStatus{message: "Result reason changed", code: code(:RESULT_REASON_CHANGED)}
    response = %PipelineDoneResponse{response_status: status}

    assert {:error, result} =  ResponseParser.process_pipeline_done_response({:ok, response})
    assert result == "Result reason changed"
  end

  test "{:ok, NOT_FOUND_response} from pipeline_done is parsed into {:error, gofer_message}" do
    status = %ResponseStatus{message: "Not found", code: code(:NOT_FOUND)}
    response = %PipelineDoneResponse{response_status: status}

    assert {:error, result} =  ResponseParser.process_pipeline_done_response({:ok, response})
    assert result == "Not found"
  end

  test '{:ok, :switch_not_defined} from pipeline_done is parsed into {:ok, ""}' do
    assert {:ok, ""} = ResponseParser.process_pipeline_done_response({:ok, :switch_not_defined})
  end

  test "{:ok, invalid_data} from pipeline_done is parsed into {:error, invalid_data}" do
    assert {:error, []} = ResponseParser.process_pipeline_done_response({:ok, []})
  end

  test "everything that is not an ok_tuple from pipeline_done is returned as is" do
    assert {:error, "Error desc"} = ResponseParser.process_pipeline_done_response({:error, "Error desc"})
  end

  defp code(key), do: ResponseCode.value(key)
end
