defmodule Test.MockFeatureService do
  @moduledoc """
    Mocks FeatureService GRPC server.
  """

  use GRPC.Server, service: InternalApi.Feature.FeatureService.Service

  def list_organization_features(_request, _stream) do
    response_type = Application.get_env(:scheduler, :mock_feature_service_response)
    respond(response_type)
  end

  defp respond("scheduler_hook") do
    alias InternalApi, as: IA

    IA.Feature.ListOrganizationFeaturesResponse.new(
      organization_features: [
        IA.Feature.OrganizationFeature.new(
          feature: IA.Feature.Feature.new(type: "scheduler_hook"),
          availability:
            IA.Feature.Availability.new(
              state: IA.Feature.Availability.State.value(:ENABLED),
              quantity: 1
            )
        ),
        IA.Feature.OrganizationFeature.new(
          feature: IA.Feature.Feature.new(type: "just_run"),
          availability:
            IA.Feature.Availability.new(
              state: IA.Feature.Availability.State.value(:HIDDEN),
              quantity: 0
            )
        )
      ]
    )
  end

  defp respond("just_run") do
    alias InternalApi, as: IA

    IA.Feature.ListOrganizationFeaturesResponse.new(
      organization_features: [
        IA.Feature.OrganizationFeature.new(
          feature: IA.Feature.Feature.new(type: "just_run"),
          availability:
            IA.Feature.Availability.new(
              state: IA.Feature.Availability.State.value(:ENABLED),
              quantity: 1
            )
        ),
        IA.Feature.OrganizationFeature.new(
          feature: IA.Feature.Feature.new(type: "scheduler_hook"),
          availability:
            IA.Feature.Availability.new(
              state: IA.Feature.Availability.State.value(:HIDDEN),
              quantity: 0
            )
        )
      ]
    )
  end

  defp respond("disabled") do
    alias InternalApi, as: IA

    IA.Feature.ListOrganizationFeaturesResponse.new(
      organization_features: [
        IA.Feature.OrganizationFeature.new(
          feature: IA.Feature.Feature.new(type: "scheduler_hook"),
          availability:
            IA.Feature.Availability.new(
              state: IA.Feature.Availability.State.value(:HIDDEN),
              quantity: 0
            )
        ),
        IA.Feature.OrganizationFeature.new(
          feature: IA.Feature.Feature.new(type: "just_run"),
          availability:
            IA.Feature.Availability.new(
              state: IA.Feature.Availability.State.value(:HIDDEN),
              quantity: 0
            )
        )
      ]
    )
  end
end
