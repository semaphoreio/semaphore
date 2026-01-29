defmodule Guard.McpOAuth.PKCE do
  @moduledoc """
  PKCE (Proof Key for Code Exchange) verification for MCP OAuth.

  Only supports S256 code_challenge_method as per best practices.
  """

  @doc """
  Verifies a code_verifier against a code_challenge using S256.

  ## Parameters
  - code_verifier: The original random string sent in the token request
  - code_challenge: The hashed challenge stored with the authorization code

  ## Returns
  - `true` if verification passes
  - `false` if verification fails
  """
  @spec verify(String.t(), String.t()) :: boolean()
  def verify(code_verifier, code_challenge) when is_binary(code_verifier) and is_binary(code_challenge) do
    computed_challenge = compute_challenge(code_verifier)
    secure_compare(computed_challenge, code_challenge)
  end

  def verify(_, _), do: false

  @doc """
  Computes the S256 code_challenge from a code_verifier.

  S256: BASE64URL(SHA256(code_verifier))
  """
  @spec compute_challenge(String.t()) :: String.t()
  def compute_challenge(code_verifier) when is_binary(code_verifier) do
    :crypto.hash(:sha256, code_verifier)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Generates a cryptographically secure code_verifier.

  Returns a 43-128 character URL-safe string.
  """
  @spec generate_verifier() :: String.t()
  def generate_verifier do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  # Constant-time string comparison to prevent timing attacks
  defp secure_compare(a, b) when byte_size(a) != byte_size(b), do: false

  defp secure_compare(a, b) do
    a_bytes = :binary.bin_to_list(a)
    b_bytes = :binary.bin_to_list(b)

    result =
      Enum.zip(a_bytes, b_bytes)
      |> Enum.reduce(0, fn {x, y}, acc -> Bitwise.bor(acc, Bitwise.bxor(x, y)) end)

    result == 0
  end
end
