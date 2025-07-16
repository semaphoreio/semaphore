defmodule FrontWeb.Plugs.FeatureEnabled do
  @behaviour Plug
  alias Front.Auth

  @type feature_name :: atom()

  @nil_uuid "00000000-0000-0000-0000-000000000000"

  @impl true
  def init(features), do: features

  @impl true
  def call(conn, features) do
    enabled = feature_enabled?(conn, features) or is_insider?(conn)

    enabled
    |> case do
      true ->
        conn

      _ ->
        conn |> Auth.render404()
    end
  end

  @spec is_insider?(Plug.Conn.t()) :: boolean()
  defp is_insider?(conn),
    do: Front.RBAC.Permissions.has?(conn.assigns.user_id, @nil_uuid, "insider.view")

  @spec feature_enabled?(Plug.Conn.t(), [feature_name]) :: boolean()
  defp feature_enabled?(conn, features) do
    organization_id = conn.assigns.organization_id

    features
    |> Enum.reduce_while(true, fn feature, acc ->
      case acc do
        true ->
          FeatureProvider.feature_enabled?(feature, param: organization_id)
          |> case do
            true -> {:cont, true}
            false -> {:halt, false}
          end

        false ->
          {:halt, false}
      end
    end)
  end
end
