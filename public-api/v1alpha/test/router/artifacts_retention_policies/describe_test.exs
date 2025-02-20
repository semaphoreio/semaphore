defmodule PipelinesAPI.ArtifactsRetentionPolicy.DescribeTest do
  use ExUnit.Case

  @user_id Ecto.UUID.generate()

  @one_week 7 * 24 * 3600
  @one_month 30 * 24 * 3600
  @one_year 365 * 24 * 3600

  alias InternalApi.Artifacthub.RetentionPolicy
  alias InternalApi.Artifacthub.RetentionPolicy.RetentionPolicyRule, as: RPR

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.DB.first(:organizations)
    owner = Support.Stubs.DB.first(:users)
    project = Support.Stubs.Project.create(org, owner)

    policy = %RetentionPolicy{
      project_level_retention_policies: [
        %RPR{selector: "/valid_value_1", age: @one_week},
        %RPR{selector: "/valid_value_2", age: @one_month},
        %RPR{selector: "/valid_value_3", age: @one_year}
      ],
      workflow_level_retention_policies: [
        %RPR{selector: "/valid_value_1", age: 2 * @one_week},
        %RPR{selector: "/valid_value_2", age: 2 * @one_month},
        %RPR{selector: "/valid_value_3", age: 2 * @one_year}
      ],
      job_level_retention_policies: [
        %RPR{selector: "/valid_value_1", age: 8 * @one_month}
      ]
    }

    artifact_id = project.api_model.spec.artifact_store_id

    Support.Stubs.Artifacthub.create_policy(artifact_id, policy)

    {:ok, %{user: owner, project: project}}
  end

  describe "GET /artifacts_retention_policies/:project_id" do
    test "returns error when project IDs mismatch", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      project = Support.Stubs.Project.create(org, ctx.user)

      assert {404, _} = describe_policies(project.id, @user_id, false)
    end

    test "returns error when user is unauthorized", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.general_settings.view")
        )
      end)

      project_id = ctx.project.id

      assert {401, _} = describe_policies(project_id, @user_id, false)
    end

    test "returns error if project does not exist" do
      project_id = UUID.uuid4()

      assert {404, "Not found"} = describe_policies(project_id, @user_id, false)
    end

    test "return error if project_id is not a valid UUID" do
      project_id = "not-a-vaild-uuid"

      assert {400, message} = describe_policies(project_id, @user_id, false)
      assert message == "project id must be a valid UUID"
    end

    test "returns 200 and updates the retention policies when given valid data", ctx do
      project_id = ctx.project.id

      assert {200, policy} = describe_policies(project_id, @user_id, true)

      assert policy == %{
               "job_level_retention_policies" => [
                 %{"age" => "8 months", "selector" => "/valid_value_1"}
               ],
               "project_level_retention_policies" => [
                 %{"age" => "1 week", "selector" => "/valid_value_1"},
                 %{"age" => "1 month", "selector" => "/valid_value_2"},
                 %{"age" => "1 year", "selector" => "/valid_value_3"}
               ],
               "workflow_level_retention_policies" => [
                 %{"age" => "2 weeks", "selector" => "/valid_value_1"},
                 %{"age" => "2 months", "selector" => "/valid_value_2"},
                 %{"age" => "2 years", "selector" => "/valid_value_3"}
               ]
             }
    end
  end

  defp describe_policies(project_id, user_id, decode?) do
    url = "localhost:4004/artifacts_retention_policies/" <> project_id
    {:ok, response} = HTTPoison.get(url, headers(user_id))

    %{:body => body, :status_code => status_code} = response

    body =
      case decode? do
        true -> Poison.decode!(body)
        false -> body
      end

    {status_code, body}
  end

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]
end
