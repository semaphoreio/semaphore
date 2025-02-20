defmodule Support.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Audit.Repo

      import Ecto
      import Ecto.Query

      alias InternalApi, as: IA

      def stub_user do
        status_ok = IA.ResponseStatus.new(code: IA.ResponseStatus.Code.value(:OK))
        response = IA.User.DescribeResponse.new(status: status_ok, name: "tester")

        GrpcMock.stub(UserMock, :describe, response)
      end

      def stub_feature do
        response =
          IA.Feature.ListOrganizationFeaturesResponse.new(
            organization_features: [
              IA.Feature.OrganizationFeature.new(
                feature: IA.Feature.Feature.new(type: "audit_logs"),
                availability:
                  IA.Feature.Availability.new(
                    state: IA.Feature.Availability.State.value(:ENABLED),
                    quantity: 1
                  )
              )
            ]
          )

        GrpcMock.stub(FeatureMock, :list_organization_features, response)
      end
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Audit.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Audit.Repo, {:shared, self()})
    end

    :ok
  end
end
