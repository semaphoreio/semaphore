defmodule FrontWeb.NotificationsView do
  use FrontWeb, :view

  def notification_name(nil), do: "[NOTIFICATION NAME]"
  def notification_name(notification), do: notification.metadata.name

  def capitalize_error_message(message) do
    capital_char =
      String.at(message, 0)
      |> String.capitalize()

    capital_char <> String.slice(message, 1..-1)
  end
end
