defmodule Support.Factories.McpOAuthAuthCode do
  alias Guard.Store.McpOAuthAuthCode

  def valid_params(user_id, overrides \\ %{}) do
    %{
      code: McpOAuthAuthCode.generate_code(),
      client_id: "test-client-#{System.unique_integer([:positive])}",
      user_id: user_id,
      redirect_uri: "http://localhost:3000/callback",
      code_challenge: Base.url_encode64(:crypto.hash(:sha256, "test-verifier"), padding: false),
      expires_at: DateTime.utc_now() |> DateTime.add(3600, :second) |> DateTime.truncate(:second)
    }
    |> Map.merge(overrides)
  end
end
