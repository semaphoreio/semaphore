defmodule Rbac.OnPrem.InitTest do
  use Rbac.RepoCase
  alias InternalApi.{ResponseStatus, Organization}
  import Rbac.Utils.Grpc, only: [grpc_error!: 2]

  @org_username "semaphore"

  describe "init/1" do
    test "should assign owner role to the default user" do
      System.put_env("ORGANIZATION_SEED_ORG_USERNAME", @org_username)

      status_ok = %ResponseStatus{code: :OK}

      user_id = Ecto.UUID.generate()

      %Rbac.FrontRepo.User{
        id: user_id,
        name: "John",
        email: "john@localhost"
      }
      |> Rbac.FrontRepo.insert()

      {:ok, _} = Support.Factories.RbacUser.insert(user_id)

      org_id = Ecto.UUID.generate()

      GrpcMock.stub(OrganizationMock, :describe, fn request, _ ->
        if request.org_username == @org_username do
          %Organization.DescribeResponse{
            status: status_ok,
            organization: %Organization.Organization{
              org_id: org_id,
              org_username: @org_username,
              name: "Semaphore",
              owner_id: user_id
            }
          }
        else
          grpc_error!(:not_found, "Organization not found")
        end
      end)

      Rbac.OnPrem.Init.init()

      scopes = Rbac.Repo.Scope |> Rbac.Repo.all(sort: [asc: :scope_name])
      assert length(scopes) == 2
      assert ["org_scope", "project_scope"] == Enum.map(scopes, & &1.scope_name)

      {:ok, owner_role} = Rbac.Repo.RbacRole.get_role_by_name("Owner", "org_scope", org_id)
      {:ok, rbi} = Rbac.RoleBindingIdentification.new(user_id: user_id, org_id: org_id)
      assert Rbac.RoleManagement.has_role(rbi, owner_role.id)
    end
  end
end
