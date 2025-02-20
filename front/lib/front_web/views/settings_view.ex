defmodule FrontWeb.SettingsView do
  use FrontWeb, :view

  def display_ip_allow_list(ip_allow_list) do
    Enum.join(ip_allow_list, ",\n")
  end

  def error_on_org_name(errors) do
    if errors && errors |> Map.has_key?("name") do
      List.first(errors["name"])
    end
  end

  def error_on_org_username(errors) do
    if errors && errors |> Map.has_key?("username") do
      List.first(errors["username"])
    end
  end

  def error_on_delete_account(errors) do
    if errors && errors.delete_account do
      errors.delete_account
    end
  end

  def error_on_org_ip_allow_list(errors) do
    if errors && errors |> Map.has_key?("ip_allow_list") do
      List.first(errors["ip_allow_list"])
    end
  end

  def error_on_org_name_class(errors) do
    if error_on_org_name(errors) do
      "b--red"
    end
  end

  def error_on_org_ip_allow_list_class(errors) do
    if error_on_org_ip_allow_list(errors) do
      "b--red"
    end
  end

  def error_on_org_username_class(errors) do
    if error_on_org_username(errors) do
      "b--red"
    end
  end

  def error_on_delete_account_class(errors) do
    if error_on_delete_account(errors) do
      "b--red"
    end
  end
end
