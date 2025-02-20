defmodule Notifications.Workers.Webhook.Signature do
  def sign(body, secret) when is_binary(secret) and secret != "",
    do: :crypto.mac(:hmac, :sha256, secret, body) |> Base.encode16(case: :lower)

  def sign(_, _), do: nil
end
