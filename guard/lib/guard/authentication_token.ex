defmodule Guard.AuthenticationToken do
  def new(opts \\ []) do
    if opts[:user_friendly] do
      # Generates a token like '7PkQBPx-A217OXG43lfM' of length 20 when encoded
      :crypto.strong_rand_bytes(15) |> Base.url_encode64()
    else
      :crypto.strong_rand_bytes(32) |> Base.encode16(case: :lower)
    end
  end

  def hash_token(token) do
    token_with_salt = "#{token}#{Application.get_env(:guard, :token_hashing_salt)}"
    :crypto.hash(:sha256, token_with_salt) |> Base.encode16(case: :lower)
  end
end
