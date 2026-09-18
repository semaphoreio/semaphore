defmodule Support.Factories do
  def status_ok do
    %InternalApi.ResponseStatus{code: InternalApi.ResponseStatus.Code.value(:OK)}
  end

  def status_not_ok(message \\ "") do
    %InternalApi.ResponseStatus{
      code: InternalApi.ResponseStatus.Code.value(:BAD_PARAM),
      message: message
    }
  end

  def project_create_response(uuid, project_req) do
    alias InternalApi.Projecthub, as: PH

    %PH.CreateResponse{
      metadata: %PH.ResponseMeta{
        status: %PH.ResponseMeta.Status{code: PH.ResponseMeta.Code.value(:OK)}
      },
      project: %PH.Project{
        metadata: %PH.Project.Metadata{
          id: uuid,
          name: project_req.metadata.name
        },
        spec: project_req.spec
      }
    }
  end
end
