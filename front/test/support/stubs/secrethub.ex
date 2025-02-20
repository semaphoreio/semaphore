defmodule Support.Stubs.Secrethub do
  alias Support.Stubs.DB
  alias InternalApi.Secrethub.{GetJWTConfigResponse, UpdateJWTConfigResponse, ClaimConfig}

  def init do
    DB.add_table(:jwt_configurations, [:id, :org_id, :project_id, :claims, :is_active])
    __MODULE__.Grpc.init()

    # Add default claims for testing
    update_jwt_config(%{
      org_id: "default_org",
      project_id: "default_project",
      claims: default_claims(),
      is_active: true
    })
  end

  def get_jwt_config(request) do
    DB.find_all_by(:jwt_configurations, :org_id, request.org_id)
    |> find_matching_config(request)
    |> build_response(request)
  end

  defp find_matching_config([], _request), do: :default

  defp find_matching_config(records, request) do
    records
    |> Enum.find(&(&1.project_id == request.project_id)) ||
      Enum.find(records, &(&1.project_id in ["", nil])) ||
      :default
  end

  defp build_response(:default, request) do
    %GetJWTConfigResponse{
      org_id: request.org_id,
      project_id: request.project_id,
      claims: default_claims(),
      is_active: true
    }
  end

  defp build_response(record, _request) do
    %GetJWTConfigResponse{
      org_id: record.org_id,
      project_id: record.project_id,
      claims: record.claims,
      is_active: record.is_active
    }
  end

  def update_jwt_config(request) do
    DB.upsert(:jwt_configurations, %{
      id: "#{request.org_id}:#{request.project_id}",
      org_id: request.org_id,
      project_id: request.project_id,
      claims: request.claims,
      is_active: request.is_active
    })

    %UpdateJWTConfigResponse{
      org_id: request.org_id,
      project_id: request.project_id
    }
  end

  defp default_claims do
    [
      %ClaimConfig{
        name: "branch",
        description: "Branch",
        is_active: true,
        is_mandatory: false,
        is_aws_tag: true,
        is_system_claim: true
      },
      %ClaimConfig{
        name: "prj_id",
        description: "Project ID",
        is_active: true,
        is_mandatory: true,
        is_aws_tag: false,
        is_system_claim: true
      },
      %ClaimConfig{
        name: "pr_branch",
        description: "Pull request branch",
        is_active: false,
        is_mandatory: false,
        is_aws_tag: true,
        is_system_claim: false
      },
      %ClaimConfig{
        name: "ppl_id",
        description: "Pipeline ID",
        is_active: false,
        is_mandatory: false,
        is_aws_tag: false,
        is_system_claim: true
      },
      %ClaimConfig{
        name: "https://aws.amazon.com/tags",
        description: "AWS Tags",
        is_active: true,
        is_mandatory: false,
        is_aws_tag: false,
        is_system_claim: true
      }
    ]
  end

  defmodule Grpc do
    def init do
      GrpcMock.stub(SecretMock, :get_jwt_config, &__MODULE__.get_jwt_config/2)
      GrpcMock.stub(SecretMock, :update_jwt_config, &__MODULE__.update_jwt_config/2)
    end

    def get_jwt_config(req, _), do: Support.Stubs.Secrethub.get_jwt_config(req)

    def update_jwt_config(req, _), do: Support.Stubs.Secrethub.update_jwt_config(req)
  end
end
