defmodule Support.FakeServices do
  alias Support.FakeServices, as: FS

  def github_token, do: "000000000000000000000000000000000000"

  def stub_responses do
    user_response =
      InternalApi.User.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        user_id: Ecto.UUID.generate(),
        name: "test_user",
        github_token: github_token()
      )

    list_response =
      InternalApi.PeriodicScheduler.ListResponse.new(
        status: InternalApi.Status.new(code: Google.Rpc.Code.value(:OK)),
        periodics: []
      )

    FunRegistry.set!(FS.UserService, :describe, user_response)

    FunRegistry.set!(FS.OrganizationService, :describe, fn req, _ ->
      InternalApi.Organization.DescribeResponse.new(
        status: InternalApi.ResponseStatus.new(code: InternalApi.ResponseStatus.Code.value(:OK)),
        organization:
          InternalApi.Organization.Organization.new(
            org_username: req.org_username,
            org_id: req.org_id
          )
      )
    end)

    FunRegistry.set!(FS.FeatureService, :list_organization_features, fn _req, _ ->
      availability = InternalApi.Feature.Availability.new(state: :ENABLED, quantity: 10)

      InternalApi.Feature.ListOrganizationFeaturesResponse.new(
        organization_features: [
          [feature: %{type: "max_projects_in_org"}, availability: availability]
        ]
      )
    end)

    FunRegistry.set!(FS.PeriodicSchedulerService, :list, list_response)
  end
end
