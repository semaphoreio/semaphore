defmodule Test.MockProjectService do
  @moduledoc """
  Mocks ProjectService GRPC server.
  """

  use GRPC.Server, service: InternalApi.Projecthub.ProjectService.Service

  alias InternalApi.Projecthub, as: API

  def describe(request, _stream) do
    response_type = Application.get_env(:scheduler, :mock_project_service_response)
    respond(request, response_type)
  end

  defp respond(request, "ok") do
    response_meta = request_meta_to_response_meta(request, code: :OK)

    Util.Proto.deep_new!(API.DescribeResponse, %{
      metadata: response_meta,
      project: project_for_response()
    })
  end

  defp respond(request, "not_found") do
    response_meta = request_meta_to_response_meta(request, code: :NOT_FOUND, message: "Not found")
    Util.Proto.deep_new!(API.DescribeResponse, %{metadata: response_meta})
  end

  defp respond(request, "failed_precondition") do
    response_meta =
      request_meta_to_response_meta(request,
        code: :FAILED_PRECONDITION,
        message: "Failed precondition"
      )

    Util.Proto.deep_new!(API.DescribeResponse, %{metadata: response_meta})
  end

  defp respond(request, "timeout") do
    :timer.sleep(6_000)

    response_meta = request_meta_to_response_meta(request, code: :OK)

    Util.Proto.deep_new!(API.DescribeResponse, %{
      metadata: response_meta,
      project: project_for_response()
    })
  end

  defp request_meta_to_response_meta(request, status_args) do
    request.metadata
    |> Map.take(~w(api_version kind req_id org_id user_id)a)
    |> Map.put(:status, Map.new(status_args))
  end

  defp project_for_response do
    %{
      metadata: %{
        id: UUID.uuid4(),
        name: "project_name"
      },
      spec: %{
        repository: %{
          id: UUID.uuid4(),
          integration_type: :GITHUB_OAUTH_TOKEN
        }
      }
    }
  end
end
