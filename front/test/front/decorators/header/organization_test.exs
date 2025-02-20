defmodule Front.Decorators.Header.OrganizationTest do
  use Front.TestCase
  alias Front.Decorators.Header.Organization, as: OrganizationHeader

  def organization_tabs do
    [
      "settings",
      "projects",
      "people",
      "activity",
      "audit",
      "billing"
    ]
  end

  describe ".is_tab_active?" do
    test "it returns true when requested path and tab path match activity" do
      conn = %{request_path: "/activity"}
      tab_path = "activity"

      assert OrganizationHeader.is_tab_active?(conn, tab_path)
    end

    test "it returns false when requested path and tab path don't match" do
      conn = %{request_path: "/projects"}
      tab_path = "/people"

      assert OrganizationHeader.is_tab_active?(conn, tab_path) == false
    end

    test "when activity path is requested, it's true for exactly one example value" do
      conn = %{request_path: "/activity"}

      assert Enum.filter(organization_tabs(), fn t ->
               OrganizationHeader.is_tab_active?(conn, t)
             end) ==
               [
                 "activity"
               ]
    end

    test "when audit path is requested, it's true for exaclty one example value" do
      conn = %{request_path: "/audit"}

      assert Enum.filter(organization_tabs(), fn t ->
               OrganizationHeader.is_tab_active?(conn, t)
             end) ==
               [
                 "audit"
               ]
    end

    test "when people path is requested, it's true for project people example value" do
      conn = %{request_path: "/people"}

      assert Enum.filter(organization_tabs(), fn t ->
               OrganizationHeader.is_tab_active?(conn, t)
             end) ==
               [
                 "people"
               ]
    end

    test "when projects path is requested, it's true for one example value" do
      conn = %{request_path: "/projects"}

      assert Enum.filter(organization_tabs(), fn t ->
               OrganizationHeader.is_tab_active?(conn, t)
             end) ==
               [
                 "projects"
               ]
    end

    test "when settings path is requested, it's true for settings" do
      conn = %{request_path: "/settings"}

      assert Enum.filter(organization_tabs(), fn t ->
               OrganizationHeader.is_tab_active?(conn, t)
             end) ==
               [
                 "settings"
               ]
    end

    test "when organization notifications path is requested, it's true for settings" do
      conn = %{request_path: "/notifications"}

      assert Enum.filter(organization_tabs(), fn t ->
               OrganizationHeader.is_tab_active?(conn, t)
             end) ==
               [
                 "settings"
               ]
    end

    test "when organization secrets path is requested, it's true for settings path" do
      conn = %{request_path: "/secrets"}

      assert Enum.filter(organization_tabs(), fn t ->
               OrganizationHeader.is_tab_active?(conn, t)
             end) ==
               [
                 "settings"
               ]
    end
  end
end
