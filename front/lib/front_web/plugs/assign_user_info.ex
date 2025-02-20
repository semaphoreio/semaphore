defmodule FrontWeb.Plug.AssignUserInfo do
  require Logger
  import Plug.Conn

  def init(options), do: options

  def call(conn, _opts) do
    user_id =
      conn
      |> get_req_header("x-semaphore-user-id")
      |> List.first()

    # fetch user data to set user_created_at assign for userpilot
    user_created_at = fetch_user_created_at(user_id)

    anonymous =
      conn
      |> get_req_header("x-semaphore-user-anonymous")
      |> List.first()
      |> anonymous?

    conn
    |> assign(:user_id, user_id)
    |> assign(:anonymous, anonymous)
    |> assign(:user_created_at, user_created_at)
  end

  defp anonymous?("true"), do: true
  defp anonymous?(_), do: false

  defp fetch_user_created_at(nil), do: nil

  defp fetch_user_created_at(user_id) do
    Front.Models.User.find(user_id, nil, [:created_at])
    |> case do
      nil -> nil
      user -> user |> Map.get(:created_at)
    end
  end
end
