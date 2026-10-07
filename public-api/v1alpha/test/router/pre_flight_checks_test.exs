defmodule Router.PreFlightChecksTest do
  use ExUnit.Case

  alias Support.Stubs.PreFlightChecks

  @user_id Ecto.UUID.generate()

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    Support.Stubs.grant_all_permissions()

    org = Support.Stubs.DB.first(:organizations)
    owner = Support.Stubs.DB.first(:users)
    project = Support.Stubs.Project.create(org, owner)

    Support.Stubs.Feature.enable_feature(org.id, :pre_flight_checks)

    {:ok, %{org: org, project: project}}
  end

  describe "GET /pre_flight_checks - organization level" do
    test "returns 404 when pre-flight checks are not configured" do
      assert {404, _} = describe_pfc(%{}, @user_id, false)
    end

    test "returns 200 with the organization configuration", ctx do
      PreFlightChecks.create_for_organization(ctx.org.id,
        commands: ["make lint", "make test"],
        secrets: ["aws-keys"],
        agent: [machine_type: "e1-standard-2", os_image: "ubuntu2004"],
        requester_id: @user_id
      )

      assert {200, response} = describe_pfc(%{})

      assert response == %{
               "commands" => ["make lint", "make test"],
               "secrets" => ["aws-keys"],
               "agent" => %{"machine_type" => "e1-standard-2", "os_image" => "ubuntu2004"},
               "requester_id" => @user_id,
               "created_at" => "2022-11-11T21:41:11.000000Z",
               "updated_at" => "2022-11-11T21:41:11.000000Z"
             }
    end

    test "returns 401 when the user lacks organization.pre_flight_checks.view" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("organization.pre_flight_checks.view")
        )
      end)

      assert {401, "Permission denied"} = describe_pfc(%{}, @user_id, false)
    end

    test "returns 403 when the pre_flight_checks feature is disabled", ctx do
      Support.Stubs.Feature.disable_feature(ctx.org.id, :pre_flight_checks)

      assert {403, message} = describe_pfc(%{}, @user_id, false)
      assert message =~ "The pre flight checks feature is not enabled for your organization"
    end
  end

  describe "GET /pre_flight_checks - project level" do
    test "returns 200 with the project configuration", ctx do
      PreFlightChecks.create_for_project(ctx.org.id, ctx.project.id,
        commands: ["checkout"],
        requester_id: @user_id
      )

      assert {200, response} = describe_pfc(%{"project_id" => ctx.project.id})

      assert response["commands"] == ["checkout"]
      assert response["requester_id"] == @user_id
    end

    test "returns 404 when the project belongs to another organization" do
      other_org = Support.Stubs.Organization.create(name: "PFC2", org_username: "pfc2")
      owner = Support.Stubs.DB.first(:users)
      other_project = Support.Stubs.Project.create(other_org, owner)

      PreFlightChecks.create_for_project(other_org.id, other_project.id, commands: ["checkout"])

      assert {404, _} = describe_pfc(%{"project_id" => other_project.id}, @user_id, false)
    end

    test "returns 401 when the user lacks project.pre_flight_checks.view", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.pre_flight_checks.view")
        )
      end)

      assert {401, "Permission denied"} =
               describe_pfc(%{"project_id" => ctx.project.id}, @user_id, false)
    end

    test "returns 400 when project_id is not a valid UUID" do
      assert {400, message} = describe_pfc(%{"project_id" => "not-a-uuid"}, @user_id, false)
      assert message == "project_id must be a valid UUID"
    end
  end

  describe "PATCH /pre_flight_checks - organization level" do
    test "returns 200 and stores the configuration", ctx do
      params = %{
        "commands" => ["make lint"],
        "secrets" => ["aws-keys"],
        "agent" => %{"machine_type" => "e1-standard-2", "os_image" => "ubuntu2004"}
      }

      assert {200, response} = apply_pfc(params)

      assert response["commands"] == ["make lint"]
      assert response["secrets"] == ["aws-keys"]
      assert response["agent"] == %{"machine_type" => "e1-standard-2", "os_image" => "ubuntu2004"}

      record = PreFlightChecks.find_for_organization(ctx.org.id)
      assert record.level == :ORGANIZATION
      assert record.model.commands == ["make lint"]
    end

    test "takes the requester_id from the x-semaphore-user-id header", ctx do
      params = %{
        "commands" => ["make lint"],
        "requester_id" => "11111111-1111-1111-1111-111111111111"
      }

      assert {200, _response} = apply_pfc(params)

      record = PreFlightChecks.find_for_organization(ctx.org.id)
      assert record.model.requester_id == @user_id
    end

    test "returns 400 when commands are empty" do
      assert {400, message} = apply_pfc(%{"commands" => []}, @user_id, false)
      assert message == "commands must be a non-empty list of strings"
    end

    test "returns 400 when commands are missing" do
      assert {400, message} = apply_pfc(%{"secrets" => ["aws-keys"]}, @user_id, false)
      assert message == "commands must be a non-empty list of strings"
    end

    test "returns 401 when the user lacks organization.pre_flight_checks.manage" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.pre_flight_checks.manage")
        )
      end)

      assert {401, "Permission denied"} =
               apply_pfc(%{"commands" => ["make lint"]}, @user_id, false)
    end
  end

  describe "PATCH /pre_flight_checks - project level" do
    test "returns 200 and stores the configuration", ctx do
      params = %{"project_id" => ctx.project.id, "commands" => ["checkout"]}

      assert {200, response} = apply_pfc(params)
      assert response["commands"] == ["checkout"]

      record = PreFlightChecks.find_for_project(ctx.project.id)
      assert record.level == :PROJECT
      assert record.model.requester_id == @user_id
      assert is_nil(PreFlightChecks.find_for_organization(ctx.org.id))
    end

    test "returns 401 when the user lacks project.pre_flight_checks.manage", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.pre_flight_checks.manage")
        )
      end)

      params = %{"project_id" => ctx.project.id, "commands" => ["checkout"]}

      assert {401, "Permission denied"} = apply_pfc(params, @user_id, false)
    end
  end

  describe "DELETE /pre_flight_checks" do
    test "returns 200 and removes the organization configuration", ctx do
      PreFlightChecks.create_for_organization(ctx.org.id, commands: ["make lint"])

      assert {200, _} = delete_pfc(%{})
      assert is_nil(PreFlightChecks.find_for_organization(ctx.org.id))
    end

    test "returns 200 and removes the project configuration", ctx do
      PreFlightChecks.create_for_project(ctx.org.id, ctx.project.id, commands: ["checkout"])

      assert {200, _} = delete_pfc(%{"project_id" => ctx.project.id})
      assert is_nil(PreFlightChecks.find_for_project(ctx.project.id))
    end

    test "returns 401 when the user lacks organization.pre_flight_checks.manage" do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions:
            Support.Stubs.all_permissions_except("organization.pre_flight_checks.manage")
        )
      end)

      assert {401, "Permission denied"} = delete_pfc(%{}, @user_id, false)
    end

    test "returns 401 when the user lacks project.pre_flight_checks.manage", ctx do
      GrpcMock.stub(RBACMock, :list_user_permissions, fn _, _ ->
        InternalApi.RBAC.ListUserPermissionsResponse.new(
          permissions: Support.Stubs.all_permissions_except("project.pre_flight_checks.manage")
        )
      end)

      assert {401, "Permission denied"} =
               delete_pfc(%{"project_id" => ctx.project.id}, @user_id, false)
    end
  end

  defp describe_pfc(params, user_id \\ @user_id, decode? \\ true) do
    url = "localhost:4004/pre_flight_checks?" <> URI.encode_query(params)
    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.get(url, headers(user_id))

    {status_code, decode(body, decode?)}
  end

  defp apply_pfc(params, user_id \\ @user_id, decode? \\ true) do
    url = "localhost:4004/pre_flight_checks"

    {:ok, %{:body => body, :status_code => status_code}} =
      HTTPoison.patch(url, Poison.encode!(params), headers(user_id))

    {status_code, decode(body, decode?)}
  end

  defp delete_pfc(params, user_id \\ @user_id, decode? \\ true) do
    url = "localhost:4004/pre_flight_checks?" <> URI.encode_query(params)

    {:ok, %{:body => body, :status_code => status_code}} = HTTPoison.delete(url, headers(user_id))

    {status_code, decode(body, decode?)}
  end

  defp decode(body, true), do: Poison.decode!(body)
  defp decode(body, false), do: body

  defp headers(user_id),
    do: [
      {"Content-type", "application/json"},
      {"x-semaphore-user-id", user_id},
      {"x-semaphore-org-id", Support.Stubs.Organization.default_org_id()}
    ]
end
