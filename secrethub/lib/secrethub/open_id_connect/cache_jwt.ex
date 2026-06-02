defmodule Secrethub.OpenIDConnect.CacheJWT do
  @moduledoc """
  Mints cache-scoped OIDC tokens used by the job-side cache runtime to obtain
  short-lived S3 credentials from Ceph via `AssumeRoleWithWebIdentity`.

  This is intentionally isolated from `Secrethub.OpenIDConnect.JWT` (the
  customer-facing OIDC token):

    * a dedicated, global issuer: `https://cache.<base_domain>`
    * a dedicated keyset (`:cache_openid_keys`)
    * a fixed audience (`ceph-cache`)

  Project isolation is NOT enforced by the descriptive claims. It is enforced by
  the Ceph project role trust policy matching a fixed `aud` plus a canonical
  `sub` produced by `subject/3`:

      org:<org_id>:project:<project_id>:access:<read_only|read_write>

  This `sub` format is a contract shared with CacheHub, which renders the
  matching trust policy. Keep both sides in sync (see ceph-support-plan-v2.md).
  """

  defmodule Token do
    @moduledoc false
    use Joken.Config, default_key: :rs256
  end

  @algo "RS256"
  @audience "ceph-cache"
  @cache_subdomain "cache"

  # The cache token must outlive a single STS session so the job-side runtime
  # can keep refreshing credentials. Regular jobs run up to 24h; we allow a
  # small buffer on top.
  @default_expires_in 3_600
  @min_expires_in 60
  @max_expires_in 90_000

  @valid_access ["read_only", "read_write"]

  # Claims advertised in the cache issuer's discovery document.
  @claims [
    "jti",
    "sub",
    "aud",
    "iss",
    "exp",
    "nbf",
    "iat",
    "org_id",
    "prj_id",
    "job_id",
    "job_type",
    "cache_access"
  ]

  def algo, do: @algo
  def audience, do: @audience
  def cache_subdomain, do: @cache_subdomain
  def claims, do: @claims

  @doc """
  The global cache issuer URL, derived from the configured base domain so it is
  environment-portable (production base domain yields `https://cache.semaphoreci.com`).
  """
  def issuer do
    domain = Application.fetch_env!(:secrethub, :domain)
    "https://#{@cache_subdomain}.#{domain}"
  end

  @doc """
  Canonical subject string. Shared contract with CacheHub trust-policy rendering.

  `org_id` and `project_id` are Semaphore UUIDs (no colons), so `:` is a
  collision-free separator.
  """
  def subject(org_id, project_id, cache_access) do
    "org:#{org_id}:project:#{project_id}:access:#{cache_access}"
  end

  @doc """
  Builds and signs a cache OIDC token for the given request.

  Returns `{:ok, token, expires_at}` where `expires_at` is the absolute unix
  expiry (seconds), or `{:error, reason}` for invalid input.
  """
  def generate_and_sign(req) do
    with {:ok, org_id} <- require_field(req.organization_id, :organization_id),
         {:ok, project_id} <- require_field(req.project_id, :project_id),
         {:ok, access} <- validate_access(req.cache_access) do
      now = Joken.current_time()
      expires_at = now + clamp_expires_in(req.expires_in)

      key = active_key()
      signer = Joken.Signer.create(@algo, key.key, %{"kid" => key.id})

      extra_claims = %{
        "iss" => issuer(),
        "aud" => @audience,
        "sub" => subject(org_id, project_id, access),
        "org_id" => org_id,
        "prj_id" => project_id,
        "job_id" => req.job_id,
        "job_type" => req.job_type,
        "cache_access" => access,
        "iat" => now,
        "nbf" => now,
        "exp" => expires_at
      }

      with {:ok, token, _claims} <- Token.generate_and_sign(extra_claims, signer) do
        {:ok, token, expires_at}
      end
    end
  end

  @doc false
  def verify(token) do
    JOSE.JWT.verify_strict(active_key().key, [@algo], token)
  end

  defp active_key, do: Secrethub.OpenIDConnect.KeyManager.active_key(:cache_openid_keys)

  defp validate_access(access) when access in @valid_access, do: {:ok, access}
  defp validate_access(_), do: {:error, :invalid_cache_access}

  defp require_field(value, _field) when is_binary(value) and value != "", do: {:ok, value}
  defp require_field(_value, field), do: {:error, {:missing_field, field}}

  defp clamp_expires_in(value) when is_integer(value) and value > 0 do
    value |> max(@min_expires_in) |> min(@max_expires_in)
  end

  defp clamp_expires_in(_value), do: @default_expires_in
end
