defmodule RepositoryHub.Stub.Feature do
  @moduledoc false

  alias InternalApi.Feature

  use GRPC.Server, service: Feature.FeatureService.Service

  @orgs_with_hook_verification [
    "9290123e-6066-41ae-8ae3-321964100dce",
    "15dc44f0-3d9e-4282-b474-11959e647f18"
  ]

  def list_organization_features(request, _stream) do
    request
    |> case do
      %{org_id: org_id} when org_id in @orgs_with_hook_verification ->
        %Feature.ListOrganizationFeaturesResponse{
          organization_features: [
            enabled_feature("experimental_strict_hook_verification")
          ]
        }

      _ ->
        %Feature.ListOrganizationFeaturesResponse{organization_features: []}
    end
  end

  defp enabled_feature(type) do
    %Feature.OrganizationFeature{
      feature: %Feature.Feature{
        name: type,
        type: type,
        description: "A feature"
      },
      availability: %Feature.Availability{
        state: :ENABLED,
        quantity: 1
      }
    }
  end
end
