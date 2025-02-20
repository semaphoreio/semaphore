defmodule Support.FakeServices do
  alias InternalApi, as: IA

  @default_project_id Ecto.UUID.generate()
  @permissions [
    "organization.secrets.view",
    "organization.secrets.manage",
    "project.secrets.view",
    "project.secrets.manage",
    "organization.secrets_policy_settings.view",
    "organization.secrets_policy_settings.manage"
  ]

  def stub_responses do
    FunRegistry.set!(Support.FakeServices.RbacService, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: @permissions)
    end)

    enable_features()
    stub_projects_list()
    stub_projects()
  end

  def stub_auth_user(permissions \\ @permissions) do
    Cachex.clear(:auth_cache)

    FunRegistry.set!(Support.FakeServices.RbacService, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: permissions)
    end)
  end

  def stub_unauth_user do
    FunRegistry.set!(Support.FakeServices.RbacService, :list_user_permissions, fn _, _ ->
      InternalApi.RBAC.ListUserPermissionsResponse.new(permissions: [])
    end)
  end

  def enable_features(features \\ ["secrets_access_policy", "project_level_secrets"]) do
    Cachex.clear(:feature_cache)

    FunRegistry.set!(Support.FakeServices.FeatureService, :list_organization_features, fn _req,
                                                                                          _ ->
      IA.Feature.ListOrganizationFeaturesResponse.new(
        organization_features:
          features
          |> Enum.map(fn feature ->
            IA.Feature.OrganizationFeature.new(
              feature: IA.Feature.Feature.new(type: feature),
              availability:
                IA.Feature.Availability.new(
                  state: IA.Feature.Availability.State.value(:ENABLED),
                  quantity: 1
                )
            )
          end)
      )
    end)
  end

  def stub_projects_list(number_of_projects \\ 5) do
    FunRegistry.set!(Support.FakeServices.ProjecthubService, :list, fn _req, _ ->
      alias InternalApi.Projecthub.ResponseMeta
      alias InternalApi.Projecthub.Project
      meta = ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))
      pagination = InternalApi.Projecthub.PaginationResponse.new(total_pages: 1)

      projects =
        Enum.reduce(1..number_of_projects, [], fn _, acc ->
          project =
            Project.new(
              metadata:
                Project.Metadata.new(
                  id: Ecto.UUID.generate(),
                  name: "project.#{Ecto.UUID.generate()}"
                ),
              spec:
                Project.Spec.new(
                  repository:
                    Project.Spec.Repository.new(
                      url: "git@github.com:/renderedtext/project-einz.git"
                    )
                )
            )

          acc ++ [project]
        end)

      InternalApi.Projecthub.ListResponse.new(
        metadata: meta,
        projects: projects,
        pagination: pagination
      )
    end)
  end

  def stub_projects(project_id \\ @default_project_id) do
    project_name = "project.#{Ecto.UUID.generate()}"

    FunRegistry.set!(Support.FakeServices.ProjecthubService, :describe, fn _req, _ ->
      alias InternalApi.Projecthub.ResponseMeta
      alias InternalApi.Projecthub.Project
      meta = ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))

      project =
        Project.new(
          metadata:
            Project.Metadata.new(
              id: project_id,
              name: project_name
            ),
          spec:
            Project.Spec.new(
              repository:
                Project.Spec.Repository.new(url: "git@github.com:/renderedtext/project-einz.git")
            )
        )

      InternalApi.Projecthub.DescribeResponse.new(metadata: meta, project: project)
    end)

    project_name
  end
end
