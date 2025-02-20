defmodule Ppl.Admin.Server do
  @moduledoc false

  use GRPC.Server, service: InternalApi.Plumber.Admin.Service

  alias Ppl.Ppls.Model.PplsQueries
  alias Ppl.PplOrigins.Model.PplOriginsQueries
  alias InternalApi.Plumber.{GetYamlResponse, TerminateAllResponse, ResponseStatus}
  alias InternalApi.Plumber.ResponseStatus.ResponseCode
  alias InternalApi.Plumber.TerminateAllRequest.Reason
  alias Util.{ToTuple, Proto}

  def get_yaml(request, _stream) do
    with {:ok, ppl_or} <-  PplOriginsQueries.get_by_id(request.ppl_id),
          yaml <- ppl_or.initial_definition || "",
          resp <- %{yaml: yaml, response_status: %{code: :OK}}
    do
      resp |> Proto.deep_new!(GetYamlResponse)
    else
      error ->
        %{response_status: %{code: :BAD_PARAM, message: to_str(error)}}
        |> Proto.deep_new!(GetYamlResponse)
    end
  end

  def terminate_all(terminate_all_request, _stream) do
    with {:ok, project_id}  <- Map.fetch(terminate_all_request, :project_id),
         {:ok, branch_name} <- Map.fetch(terminate_all_request, :branch_name),
         reason             <- terminate_all_request.reason |> Reason.key(),
         {:ok, t_params}    <- terminate_params(project_id, branch_name, reason),
         {:ok, number}      <- PplsQueries.terminate_all(t_params)
    do
        %{response_status: ok_status("Termination started for #{number} pipelines.")}
         |> TerminateAllResponse.new()
    else
      e ->  %{response_status: error_status(e)} |> TerminateAllResponse.new()
    end
  end

  defp terminate_params(project_id, branch_name, reason) do
    %{project_id: project_id,
      branch_name: branch_name,
      terminate_request: "stop",
      terminate_request_desc: description(reason),
      terminated_by:  terminated_by(reason)
    } |> ToTuple.ok()
  end

  defp description(:ADMIN_ACTION), do: "admin action"
  defp description(:BRANCH_DELETION), do: "branch deletion"

  defp terminated_by(:ADMIN_ACTION), do: "admin"
  defp terminated_by(:BRANCH_DELETION), do: "branch deletion"

  defp ok_status(message),
    do: ResponseStatus.new(code: ResponseCode.value(:OK), message: message)

  defp error_status({:error, message}),
    do: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: to_str(message))
  defp error_status(message),
    do: ResponseStatus.new(code: ResponseCode.value(:BAD_PARAM), message: to_str(message))

  defp to_str(term) when is_binary(term), do: term
  defp to_str(term), do: inspect(term)
end
