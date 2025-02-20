defmodule Secrethub.OpenIDConnect.KeyManager do
  @moduledoc """
  Module responsible for managing PEM keys that are used
  to sign OIDC tokens. At any moment, the system can have
  multiple registered PEM keys.

  The keys are stored in a directory (see :openid_keys_path)
  and every key is named by the unix timestamp when it was
  generated.

  Example content of the directory
    - 166003003.pem
    - 166003002.pem
    - 166003001.pem

  The module also facilitates key rotation in on-prem version:
  - A key with timestamp T becomes active after T + security-factor * cache-max-age.
  By default, this means a key with timestamp T is active post T + 3 days.
  - For public keys, if the active key has timestamp T, then keys older than
  T - security-factor * cache-max-age are excluded from the public key set.
  Essentially, keys older than T - 3 days are disregarded. Retaining historical keys
  is vital to enable clients to verify keys even after key rotation.

  In SaaS at the moment all the keys are returned as public keys. Active key is
  the key with the latest timestamp.

  Our OIDC tokens have a 24 hour lifetime, which means that old keys
  should be kept in this list for at least 24 hours when a new key is
  introduced.

  To generate a new key for testing, execute:

    > openssl genrsa -out priv/openid_keys_in_tests/$(date +%s).pem 2048
  """

  use Agent

  defstruct [
    :keys,
    :active_key
  ]

  @cache_security_factor 3

  def start_link(name: agent_name, keys_path: keys_path) do
    if not File.exists?(keys_path) do
      raise "OpenID Keys path #{keys_path} does not exists"
    end

    Agent.start_link(fn -> load_keys(keys_path) end, name: agent_name)
  end

  def active_key(agent_name) do
    if Secrethub.on_prem?() do
      Agent.get(agent_name, fn s -> select_active_key(s.keys) end)
    else
      Agent.get(agent_name, fn s -> s.active_key end)
    end
  end

  def public_keys(agent_name) do
    if Secrethub.on_prem?() do
      public_keys_on_prem(agent_name)
    else
      Agent.get(agent_name, fn s -> s.keys end)
    end
    |> Enum.map(fn k -> k.public_key end)
  end

  defp public_keys_on_prem(agent_name) do
    active_key = active_key(agent_name)
    key_time_limit = active_key.timestamp - @cache_security_factor * cache_max_age_in_seconds()

    keys = Agent.get(agent_name, fn s -> s.keys end)

    filtered_keys =
      keys
      |> Enum.filter(fn k -> k.timestamp >= key_time_limit end)

    if Enum.empty?(filtered_keys) do
      keys
    else
      filtered_keys
    end
  end

  def load_keys(keys_path) do
    files = list_pem_files(keys_path)

    keys =
      files
      |> Enum.map(fn f -> load_one_key(keys_path, f) end)
      |> sort_by_timestamp()

    %__MODULE__{
      keys: keys,
      active_key: Enum.at(keys, 0)
    }
  end

  def cache_max_age_in_seconds,
    do: Application.get_env(:secrethub, :openid_keys_cache_max_age_in_s)

  defp select_active_key(keys) do
    key_time_limit =
      DateTime.to_unix(DateTime.utc_now()) - @cache_security_factor * cache_max_age_in_seconds()

    filtered_keys =
      keys
      |> Enum.filter(fn k -> k.timestamp < key_time_limit end)
      |> sort_by_timestamp()

    if Enum.empty?(filtered_keys) do
      keys
    else
      filtered_keys
    end
    |> List.first()
  end

  defp list_pem_files(keys_path) do
    with {:ok, files} <- File.ls(keys_path) do
      files |> Enum.filter(fn f -> Path.extname(f) == ".pem" end)
    end
  end

  defp load_one_key(keys_path, f) do
    alias Secrethub.OpenIDConnect.Key

    Key.load(keys_path, f)
  end

  defp sort_by_timestamp(keys) do
    keys |> Enum.sort(fn a, b -> a.timestamp > b.timestamp end)
  end
end
