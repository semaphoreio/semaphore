defmodule Front.CiAssistant.Token do
  @moduledoc """
  Mints short-lived HMAC tokens for CI Assistant WebSocket authentication.

  The token format is: base64url(payload).base64url(hmac-sha256(secret, payload))
  where payload is JSON with user_id, org_id, and exp (unix timestamp).

  These tokens are only used for connection establishment (60s TTL).
  """

  @ttl_seconds 60

  def mint(user_id, org_id) do
    secret = Application.fetch_env!(:front, :ci_assistant_hmac_secret)
    exp = System.system_time(:second) + @ttl_seconds
    payload = Poison.encode!(%{user_id: user_id, org_id: org_id, exp: exp})
    signature = :crypto.mac(:hmac, :sha256, secret, payload)
    Base.url_encode64(payload, padding: false) <> "." <> Base.url_encode64(signature, padding: false)
  end
end
