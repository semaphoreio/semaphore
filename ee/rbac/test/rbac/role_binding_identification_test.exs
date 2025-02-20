defmodule Rbac.RoleBindingIdentification.Test do
  use ExUnit.Case, async: true

  alias Rbac.RoleBindingIdentification, as: RBI

  @user_uuid "27676bb0-dfb4-4635-a02e-d206a7faa8de"
  @project_uuid "37676bb0-dfb4-4635-a02e-d206a7faa8da"
  @org_uuid "47676bb0-dfb4-4635-a02e-d206a7faa8dc"

  describe "new/1" do
    test "user id not valid" do
      {message, _} =
        RBI.new(%{
          :user_id => "non-valid-uud"
        })

      assert message == :error
    end

    test ":org_id not given, and :project_id is empty string" do
      {message, rbi_struct} = RBI.new(user_id: @user_uuid, project_id: "")

      assert message == :ok
      assert rbi_struct[:user_id] == @user_uuid
      assert rbi_struct[:org_id] == nil
      assert rbi_struct[:project_id] == nil
    end

    test "all fields are present" do
      {message, rbi_struct} =
        RBI.new(
          user_id: @user_uuid,
          org_id: @org_uuid,
          project_id: @project_uuid
        )

      assert message == :ok
      assert rbi_struct[:user_id] == @user_uuid
      assert rbi_struct[:org_id] == @org_uuid
      assert rbi_struct[:project_id] == @project_uuid
    end
  end

  describe "generate_cache_key/1" do
    test "user id not present" do
      {_, rbi} = RBI.new(%{})
      ret_message = RBI.generate_cache_key(rbi)
      assert ret_message == :error
    end

    test "org_id not present" do
      {_, rbi} =
        RBI.new(%{
          :user_id => @user_uuid
        })

      key = RBI.generate_cache_key(rbi)
      assert key == "user:#{@user_uuid}_org:*_project:*"
    end

    test "proj_id not present" do
      {_, rbi} =
        RBI.new(%{
          :user_id => @user_uuid,
          :org_id => @org_uuid
        })

      key = RBI.generate_cache_key(rbi)

      assert key ==
               "user:#{@user_uuid}_org:#{@org_uuid}_project:*"
    end

    test "all fields present" do
      {_, rbi} =
        RBI.new(%{
          :user_id => @user_uuid,
          :org_id => @org_uuid,
          :project_id => @project_uuid
        })

      key = RBI.generate_cache_key(rbi)

      assert key ==
               "user:#{@user_uuid}_org:#{@org_uuid}_project:#{@project_uuid}"
    end
  end

  describe "generate_all_possible_keys/1" do
    test "user id not present" do
      {_, rbi} = RBI.new(%{})
      ret_message = RBI.generate_cache_key(rbi)
      assert ret_message == :error
    end

    test "org_id not present" do
      {_, rbi} =
        RBI.new(%{
          :user_id => @user_uuid
        })

      keys = RBI.generate_all_possible_keys(rbi)
      expected_keys = ["user:#{@user_uuid}_org:*_project:*"]
      assert Enum.sort(keys) == Enum.sort(expected_keys)
    end

    test "proj_id not present" do
      {_, rbi} =
        RBI.new(%{
          :user_id => @user_uuid,
          :org_id => @org_uuid
        })

      keys = RBI.generate_all_possible_keys(rbi)

      expected_keys = [
        "user:#{@user_uuid}_org:#{@org_uuid}_project:*",
        "user:#{@user_uuid}_org:*_project:*"
      ]

      assert Enum.sort(keys) == Enum.sort(expected_keys)
    end

    test "all fields present" do
      {_, rbi} =
        RBI.new(%{
          :user_id => @user_uuid,
          :org_id => @org_uuid,
          :project_id => @project_uuid
        })

      keys = RBI.generate_all_possible_keys(rbi)

      expected_keys = [
        "user:#{@user_uuid}_org:#{@org_uuid}_project:#{@project_uuid}",
        "user:#{@user_uuid}_org:#{@org_uuid}_project:*",
        "user:#{@user_uuid}_org:*_project:*"
      ]

      assert Enum.sort(keys) == Enum.sort(expected_keys)
    end
  end
end
