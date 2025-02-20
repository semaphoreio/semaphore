defmodule Secrethub.OpenIDConnect.Key do
  @moduledoc """
  A module for managing PEM keys, loading them from disk,
  generating a unique ID, extracting the public key.

  Do not use this module directly. Use the KeyManager.
  """
  defstruct [
    :path,
    :key,
    :id,
    :public_key,
    :timestamp
  ]

  require Logger

  @doc """
  Loads a PEM key from disk.

  Example:
    load("priv/openid_keys", "16123131231.pem")
  """
  def load(path, file) do
    full_path = Path.join(path, file)

    Logger.info("Loading OpenID Key file: #{path}/#{file}")

    key = JOSE.JWK.from_pem_file(full_path)

    if key == [] do
      raise "Failed to load PEM key from #{path}/#{file}."
    end

    public_key = extract_public_key(key)
    key_id = generate_key_id(public_key)

    public_key = Map.merge(public_key, %{"kid" => key_id})

    %__MODULE__{
      timestamp: parse_timestamp_from_file_name(file),
      path: full_path,
      key: JOSE.JWK.to_map(key) |> elem(1),
      public_key: public_key,
      id: key_id
    }
  end

  @doc """
    Takes a JOSE key pair, and extracts the public key
    part from it.
  """
  @spec extract_public_key(Map.t()) :: Map.t()
  defp extract_public_key(key) do
    key
    |> JOSE.JWK.to_map()
    |> JOSE.JWK.to_public()
    |> JOSE.JWK.to_map()
    |> elem(1)
  end

  @doc """
    Takes an input file path like 1660038999.pem
    and extracts the unix timestamp from it.

    Returns 1660038999 as integer.
  """
  @spec parse_timestamp_from_file_name(String.t()) :: Integer.t()
  defp parse_timestamp_from_file_name(pem_file_name) do
    {timestamp, _} = Integer.parse(pem_file_name, 10)

    timestamp
  end

  @doc """
    Takes the public key and generates a key id for it.

    Key IDs are necessary for a proper answer in the .well-knonw/jwks
    response. The key can be anything, and it is used mostly for debugging
    purposes. The nice quality it must have is to uniquely identify a given
    pair set.

    Stack Overflow suggested using MD5 of the public key.
  """
  @spec generate_key_id(Map.t()) :: String.t()
  defp generate_key_id(public_key) do
    key_value = Map.get(public_key, "n")

    :crypto.hash(:md5, key_value)
    |> Base.encode16(case: :lower)
  end
end
