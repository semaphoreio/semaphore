defmodule Guard.OIDC.Token do
  require Logger

  def decrypt(token_enc, user_id) do
    case Guard.Encryptor.decrypt(Guard.OIDC.TokenEncryptor, token_enc, "semaphore-#{user_id}") do
      {:ok, token} -> {:ok, token}
      {:error, _} -> {:error, :decrypt_error}
    end
  end

  def encrypt(token, user_id) do
    case Guard.Encryptor.encrypt(Guard.OIDC.TokenEncryptor, token, "semaphore-#{user_id}") do
      {:ok, token_enc} ->
        {:ok, token_enc}

      {:error, _} ->
        #
        # In this case, we refresh the session without setting the new refresh token
        # On the next refresh, the session will be expired, and the user will be redirected to the login page.
        # As an improvement in the future, we can start an async task that will try to encrypt the refresh token
        # and update the session.
        #
        Logger.error("Failed to encrypt refresh token for user #{user_id}")

        {:ok, nil}
    end
  end
end
