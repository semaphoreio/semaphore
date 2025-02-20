defmodule Rbac.Api.Middleware.UpdateToken do
  @behaviour Tesla.Middleware

  def call(env, next, opts) do
    token_fetcher = Keyword.fetch!(opts, :token_fetcher)

    case Tesla.run(env, next) do
      {:ok, %Tesla.Env{status: 401} = env} ->
        {:ok, new_token} = token_fetcher.()

        new_env = Tesla.put_header(env, "authorization", "Bearer " <> new_token)
        Tesla.run(new_env, next)

      other ->
        other
    end
  end
end
