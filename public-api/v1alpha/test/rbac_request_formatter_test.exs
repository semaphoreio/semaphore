defmodule PipelinesAPI.RBACClient.RequestFormatter.Test do
  use ExUnit.Case

  alias InternalApi.RBAC
  alias PipelinesAPI.RBACClient.RequestFormatter

  @org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @role_id "7d111358-3b35-4836-ab23-60e043b5edab"
  @requester_id "37d7df48-7e34-4970-85ad-2a37e1eaf5b8"

  describe "form_modify_role_request/1" do
    test "sets requester_id on the request" do
      role = RBAC.Role.new(name: "custom-role", org_id: @org_id)

      {:ok, request} =
        RequestFormatter.form_modify_role_request(%{role: role, requester_id: @requester_id})

      assert request.role == role
      assert request.requester_id == @requester_id
    end

    test "returns user error when requester_id is missing" do
      role = RBAC.Role.new(name: "custom-role", org_id: @org_id)

      assert {:error, {:user, _}} = RequestFormatter.form_modify_role_request(%{role: role})
    end
  end

  describe "form_destroy_role_request/1" do
    test "sets requester_id on the request" do
      {:ok, request} =
        RequestFormatter.form_destroy_role_request(%{
          role_id: @role_id,
          org_id: @org_id,
          requester_id: @requester_id
        })

      assert request.role_id == @role_id
      assert request.org_id == @org_id
      assert request.requester_id == @requester_id
    end

    test "returns user error when requester_id is missing" do
      assert {:error, {:user, _}} =
               RequestFormatter.form_destroy_role_request(%{role_id: @role_id, org_id: @org_id})
    end
  end
end
