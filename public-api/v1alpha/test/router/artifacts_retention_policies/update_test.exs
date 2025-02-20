defmodule PipelinesAPI.ArtifactsRetentionPolicy.UpdateTest do
  use ExUnit.Case

  @user_id Ecto.UUID.generate()

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.DB.first(:organizations)
    owner = Support.Stubs.DB.first(:users)
    project = Support.Stubs.Project.create(org, owner)

    {:ok, %{user: owner, project: project}}
  end

  describe "POST /artifacts_retention_policies" do
    test "returns error when project IDs mismatch", ctx do
      org = Support.Stubs.Organization.create(name: "RT2", org_username: "rt2")
      project = Support.Stubs.Project.create(org, ctx.user)

      request = %{
        project_id: project.id,
        project_level_retention_policies: [%{selector: ".*", age: "2 weeks"}]
      }

      assert {404, _} = update_policies(request, @user_id, false)
    end

    test "returns error when user is unauthorized", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.general_settings.manage")
        )
      end)

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [%{selector: ".*", age: "2 weeks"}]
      }

      assert {401, _} = update_policies(request, @user_id, false)
    end

    test "returns error if project does not exist" do
      request = %{
        project_id: UUID.uuid4(),
        project_level_retention_policies: [%{selector: ".*", age: "2 weeks"}]
      }

      assert {404, "Not found"} = update_policies(request, @user_id, false)
    end

    test "return error if request paremeters are invalid", ctx do
      # the selector field is not a string

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [
          %{selector: "/valid_value_1", age: "1 week"},
          %{selector: 123, age: "2 weeks"},
          %{selector: "/valid_value_2", age: "3 weeks"}
        ]
      }

      assert {400, message} = update_policies(request, @user_id, false)
      assert message == "the 'selector' filed must be a non-empty string"

      # the selector field is an empty string

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [
          %{selector: "/valid_value_1", age: "1 week"},
          %{selector: "", age: "2 weeks"},
          %{selector: "/valid_value_2", age: "3 weeks"}
        ]
      }

      assert {400, message} = update_policies(request, @user_id, false)
      assert message == "the 'selector' filed must be a non-empty string"

      # the selector field is missing

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [
          %{selector: "/valid_value_1", age: "1 week"},
          %{age: "2 weeks"},
          %{selector: "/valid_value_2", age: "3 weeks"}
        ]
      }

      assert {400, message} = update_policies(request, @user_id, false)
      assert message == "the 'selector' filed must be a non-empty string"

      # the age field is not a string

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [
          %{selector: "/valid_value_1", age: "1 week"},
          %{selector: ".*", age: 123},
          %{selector: "/valid_value_2", age: "3 weeks"}
        ]
      }

      assert {400, message} = update_policies(request, @user_id, false)

      assert message ==
               "the 'age' fields must be a string, valid examples: 5 days, 1 week, 2 weeks, 3 months, 4 years"

      # the age field is an empty string

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [
          %{selector: "/valid_value_1", age: "1 week"},
          %{selector: ".*", age: ""},
          %{selector: "/valid_value_2", age: "3 weeks"}
        ]
      }

      assert {400, message} = update_policies(request, @user_id, false)

      assert message ==
               "the 'age' fields must be a string, valid examples: 5 days, 1 week, 2 weeks, 3 months, 4 years"

      # the age field is not in a valid format

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [
          %{selector: "/valid_value_1", age: "1 week"},
          %{selector: ".*", age: "123"},
          %{selector: "/valid_value_2", age: "3 weeks"}
        ]
      }

      assert {400, message} = update_policies(request, @user_id, false)

      assert message ==
               "invalid 'age' value: '123' - valid examples: 5 days, 1 week, 2 weeks, 3 months, 4 years"

      # all policy configurations are missing

      request = %{project_id: ctx.project.id}
      assert {400, message} = update_policies(request, @user_id, false)
      assert message == "at least one retention policy configuration must be defined"

      # all policy configurations are empty lists

      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [],
        workflow_level_retention_policies: [],
        job_level_retention_policies: []
      }

      assert {400, message} = update_policies(request, @user_id, false)
      assert message == "at least one retention policy configuration must be defined"
    end

    test "returns 200 and updates the retention policies when given valid data", ctx do
      request = %{
        project_id: ctx.project.id,
        project_level_retention_policies: [
          %{selector: "/valid_value_1", age: "1 week"},
          %{selector: "/valid_value_2", age: "1 month"},
          %{selector: "/valid_value_3", age: "1 year"}
        ],
        workflow_level_retention_policies: [
          %{selector: "/valid_value_1", age: "2 weeks"},
          %{selector: "/valid_value_2", age: "2 months"},
          %{selector: "/valid_value_3", age: "2 years"}
        ],
        job_level_retention_policies: [%{selector: "/valid_value_1", age: "8 months"}]
      }

      assert {200, policy} = update_policies(request, @user_id, true)

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

  defp update_policies(request, user_id, decode?) do
    url = "localhost:4004/artifacts_retention_policies"
    request = Poison.encode!(request)
    {:ok, response} = HTTPoison.post(url, request, headers(user_id))

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
