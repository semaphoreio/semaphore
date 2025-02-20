defmodule Front.RBAC.MembersTest do
  use ExUnit.Case, async: false

  alias Front.RBAC.Members
  alias InternalApi.RBAC.ListAccessibleProjectsResponse

  describe ".list_accessible_projects" do
    test "no access to any projects -> empty list" do
      GrpcMock.stub(
        RBACMock,
        :list_accessible_projects,
        ListAccessibleProjectsResponse.new(project_ids: [])
      )

      assert Members.list_accessible_projects(Ecto.UUID.generate(), Ecto.UUID.generate()) ==
               {:ok, []}
    end

    test "access to some projects - returns list" do
      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      GrpcMock.stub(
        RBACMock,
        :list_accessible_projects,
        ListAccessibleProjectsResponse.new(project_ids: [project_id])
      )

      assert Members.list_accessible_projects(org_id, user_id) == {:ok, [project_id]}
    end

    test "grpc error - returns error" do
      GrpcMock.stub(RBACMock, :list_accessible_projects, fn _, _ ->
        raise GRPC.RPCError,
          status: GRPC.Status.unknown(),
          message: "some error here"
      end)

      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      assert Members.list_accessible_projects(org_id, user_id) ==
               {:error, %GRPC.RPCError{status: 2, message: "some error here"}}
    end
  end

  describe ".filter_projects" do
    test "returns only accessible projects" do
      id1 = Ecto.UUID.generate()
      id2 = Ecto.UUID.generate()
      id3 = Ecto.UUID.generate()

      GrpcMock.stub(
        RBACMock,
        :list_accessible_projects,
        ListAccessibleProjectsResponse.new(project_ids: [id1, id2])
      )

      all_projects = [
        %{id: id1},
        %{id: id2},
        %{id: id3}
      ]

      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()

      assert Members.filter_projects(all_projects, org_id, user_id) == [
               %{id: id1},
               %{id: id2}
             ]
    end

    test "grpc error - returns empty list" do
      GrpcMock.stub(RBACMock, :list_accessible_projects, fn _, _ ->
        raise GRPC.RPCError,
          status: GRPC.Status.unknown(),
          message: "some error here"
      end)

      org_id = Ecto.UUID.generate()
      user_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()
      assert Members.filter_projects([%{id: project_id}], org_id, user_id) == []
    end
  end
end
