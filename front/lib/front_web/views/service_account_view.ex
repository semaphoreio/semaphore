defmodule FrontWeb.ServiceAccountView do
  use FrontWeb, :view

  alias Front.Models.ServiceAccount

  def render("index.json", %{service_accounts: service_accounts, total_pages: total_pages}) do
    %{
      service_accounts: Enum.map(service_accounts, &service_account_json/1),
      total_pages: total_pages
    }
  end

  def render("show.json", assigns = %{service_account: service_account = %ServiceAccount{}}) do
    data = service_account_json(service_account)

    # Only include api_token if it's present (on create/regenerate)
    case Map.get(assigns, :api_token) do
      nil -> data
      token -> Map.put(data, :api_token, token)
    end
  end

  defp service_account_json(service_account = %ServiceAccount{}) do
    %{
      id: service_account.id,
      name: service_account.name,
      description: service_account.description,
      created_at: format_datetime(service_account.created_at),
      updated_at: format_datetime(service_account.updated_at),
      deactivated: service_account.deactivated,
      roles: Enum.map(service_account.roles, &role_json/1)
    }
  end

  defp role_json(role) do
    %{
      id: role.id,
      name: role.name,
      source: role.source,
      color: FrontWeb.PeopleView.map_role_to_colour(role.name)
    }
  end

  defp format_datetime(nil), do: nil

  defp format_datetime(datetime = %DateTime{}) do
    DateTime.to_iso8601(datetime)
  end
end
