defmodule Test.Support.Mocks.FeatureServer do
  @moduledoc """
  Test mock for the Feature (FeatureHub) gRPC service.

  Returns the `sparse_checkout_init_job` and `job_level_partial_rerun`
  features as ENABLED for every organization, so tests can exercise the
  optimized checkout branch and the job-level copy partition branch.
  """

  use GRPC.Server, service: InternalApi.Feature.FeatureService.Service

  alias InternalApi.Feature.{
    ListOrganizationFeaturesResponse,
    OrganizationFeature,
    Feature,
    Availability
  }

  def list_organization_features(_request, _stream) do
    ListOrganizationFeaturesResponse.new(
      organization_features: [
        OrganizationFeature.new(
          feature:
            Feature.new(
              type: "sparse_checkout_init_job",
              name: "sparse_checkout_init_job"
            ),
          availability: Availability.new(state: Availability.State.value(:ENABLED), quantity: 1)
        ),
        OrganizationFeature.new(
          feature:
            Feature.new(
              type: "job_level_partial_rerun",
              name: "job_level_partial_rerun"
            ),
          availability: Availability.new(state: Availability.State.value(:ENABLED), quantity: 1)
        )
      ]
    )
  end
end
