defmodule Support.Factories.Guard do
  alias InternalApi.Guard.{FilterResponse, Resource}

  def filter_response(id) do
    %FilterResponse{
      resources: [
        %Resource{
          id: id,
          type: Resource.Type.value(:Project),
          name: "",
          project_id: "",
          org_id: ""
        }
      ]
    }
  end

  def empty do
    %FilterResponse{
      resources: []
    }
  end

  def resources(resources) do
    %FilterResponse{
      resources: resources
    }
  end

  def empty_list do
    InternalApi.Guard.ListResponse.new(
      status: Support.Factories.status_ok(),
      users: []
    )
  end
end
