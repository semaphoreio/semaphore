defmodule Rbac.Store.ProjectAccess.Test do
  use Rbac.RepoCase, async: false

  import Mock
  alias Rbac.Store.ProjectAccess

  @store_backend Application.compile_env(:rbac, :key_value_store_backend)
  @project_access_store_name Application.compile_env(:rbac, :project_access_store_name)

  @user_id Ecto.UUID.generate()
  @org_id Ecto.UUID.generate()
  @key "user:#{@user_id}_org:#{@org_id}"
  @project1_id Ecto.UUID.generate()
  @project2_id Ecto.UUID.generate()

  setup do
    @store_backend.clear(@project_access_store_name)
    :ok
  end

  describe "get_list_of_projects/2" do
    test "cache cant be reached" do
      with_mocks [
        {@store_backend, [],
         [get: fn @project_access_store_name, @key -> {:error, "Cant reach cache"} end]},
        {Rbac.Store.UserPermissions, [], [read_user_permissions: fn _ -> "" end]}
      ] do
        assert [] = ProjectAccess.get_list_of_projects(@user_id, @org_id)
      end
    end

    test "given key doesn't exist in cache" do
      assert [] = ProjectAccess.get_list_of_projects(@user_id, @org_id)
    end

    test "given key exists in cache" do
      @store_backend.put(@project_access_store_name, @key, @project1_id)
      assert [@project1_id] = ProjectAccess.get_list_of_projects(@user_id, @org_id)
    end

    test "user_has access to multiple projects" do
      @store_backend.put(@project_access_store_name, @key, @project1_id <> "," <> @project2_id)
      assert [@project1_id, @project2_id] = ProjectAccess.get_list_of_projects(@user_id, @org_id)
    end

    test "user has org-wide access to all projects" do
      {:ok, _project} = Support.Factories.Project.insert(id: @project1_id, org_id: @org_id)
      {:ok, _non_org_project} = Support.Factories.Project.insert(id: @project2_id)

      with_mock Rbac.Store.UserPermissions,
        read_user_permissions: fn _ -> "project.view" end do
        assert [@project1_id] = ProjectAccess.get_list_of_projects(@user_id, @org_id)
      end
    end
  end

  describe "add_project_access/3" do
    test "when this user has no access to any projects prior" do
      assert :ok == ProjectAccess.add_project_access(@user_id, @org_id, @project1_id)
      assert {:ok, @project1_id} == @store_backend.get(@project_access_store_name, @key)
    end

    test "when user already has access to the given project" do
      @store_backend.put(@project_access_store_name, @key, @project1_id)
      assert :ok == ProjectAccess.add_project_access(@user_id, @org_id, @project1_id)
      assert {:ok, @project1_id} == @store_backend.get(@project_access_store_name, @key)
    end

    test "when user already has acces to some other projects" do
      @store_backend.put(@project_access_store_name, @key, @project2_id)
      assert :ok == ProjectAccess.add_project_access(@user_id, @org_id, @project1_id)
      {:ok, projects} = @store_backend.get(@project_access_store_name, @key)
      assert String.split(projects, ",") -- [@project1_id, @project2_id] == []
    end
  end

  describe "remove_project_access" do
    test "when this user has no access to any project" do
      assert :ok == ProjectAccess.remove_project_access(@user_id, @org_id, @project1_id)
      assert {:ok, nil} == @store_backend.get(@project_access_store_name, @key)
    end

    test "when user has access only to this one project" do
      @store_backend.put(@project_access_store_name, @key, @project1_id)
      assert :ok == ProjectAccess.remove_project_access(@user_id, @org_id, @project1_id)
      assert {:ok, nil} == @store_backend.get(@project_access_store_name, @key)
    end

    test "when user has access to multiple projects" do
      @store_backend.put(@project_access_store_name, @key, @project1_id <> "," <> @project2_id)
      assert :ok == ProjectAccess.remove_project_access(@user_id, @org_id, @project1_id)
      assert {:ok, @project2_id} == @store_backend.get(@project_access_store_name, @key)
    end

    test "when user does not have access to this project" do
      @store_backend.put(@project_access_store_name, @key, @project2_id)

      assert {:error, "Project removal unseccessful"} ==
               ProjectAccess.remove_project_access(@user_id, @org_id, @project1_id)
    end
  end
end
