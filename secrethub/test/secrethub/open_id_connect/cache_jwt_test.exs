defmodule Secrethub.OpenIDConnect.CacheJWTTest do
  use ExUnit.Case, async: false

  alias Secrethub.OpenIDConnect.{CacheJWT, KeyManager}
  alias InternalApi.Secrethub.GenerateCacheOpenIDConnectTokenRequest, as: Request

  @org_id "5f1e0c2a-0000-0000-0000-000000000001"
  @project_id "9c2a7b10-0000-0000-0000-000000000002"

  setup do
    # The cache keyset is isolated from the customer-facing keyset.
    start_supervised!(
      {KeyManager, [name: :cache_openid_keys, keys_path: "priv/cache_openid_keys_in_tests"]}
    )

    previous_domain = Application.get_env(:secrethub, :domain)
    Application.put_env(:secrethub, :domain, "semaphoreci.com")

    on_exit(fn ->
      if previous_domain do
        Application.put_env(:secrethub, :domain, previous_domain)
      else
        Application.delete_env(:secrethub, :domain)
      end
    end)

    :ok
  end

  defp request(overrides \\ %{}) do
    defaults = %{
      organization_id: @org_id,
      project_id: @project_id,
      job_id: "job-123",
      job_type: "pipeline_job",
      cache_access: "read_write",
      expires_in: 3_600
    }

    Request.new(Map.merge(defaults, overrides) |> Map.to_list())
  end

  defp claims(token) do
    {true, %JOSE.JWT{fields: fields}, _jws} = CacheJWT.verify(token)
    fields
  end

  describe "subject/3" do
    test "builds the canonical, colon-delimited subject" do
      assert CacheJWT.subject(@org_id, @project_id, "read_only") ==
               "org:#{@org_id}:project:#{@project_id}:access:read_only"
    end
  end

  describe "issuer/0" do
    test "is the global cache issuer derived from the base domain" do
      assert CacheJWT.issuer() == "https://cache.semaphoreci.com"
    end
  end

  describe "generate_and_sign/1" do
    test "mints a verifiable token with the expected cache claims" do
      assert {:ok, token, expires_at} = CacheJWT.generate_and_sign(request())

      fields = claims(token)

      assert fields["iss"] == "https://cache.semaphoreci.com"
      assert fields["aud"] == "ceph-cache"
      assert fields["sub"] == "org:#{@org_id}:project:#{@project_id}:access:read_write"
      assert fields["org_id"] == @org_id
      assert fields["prj_id"] == @project_id
      assert fields["job_id"] == "job-123"
      assert fields["job_type"] == "pipeline_job"
      assert fields["cache_access"] == "read_write"
      assert fields["exp"] == expires_at
      assert is_binary(fields["jti"]) and fields["jti"] != ""
    end

    test "encodes read_only access in the subject" do
      assert {:ok, token, _} = CacheJWT.generate_and_sign(request(%{cache_access: "read_only"}))
      assert claims(token)["sub"] == "org:#{@org_id}:project:#{@project_id}:access:read_only"
    end

    test "rejects an invalid cache_access" do
      assert {:error, :invalid_cache_access} =
               CacheJWT.generate_and_sign(request(%{cache_access: "admin"}))
    end

    test "requires organization_id and project_id" do
      assert {:error, {:missing_field, :organization_id}} =
               CacheJWT.generate_and_sign(request(%{organization_id: ""}))

      assert {:error, {:missing_field, :project_id}} =
               CacheJWT.generate_and_sign(request(%{project_id: ""}))
    end

    test "defaults to 24h + 15m when expires_in is unset and clamps to that maximum" do
      now = Joken.current_time()

      # Unset/zero -> default to the longest possible job (24h) + 15m buffer,
      # so a token injected at job start outlives a 24h job.
      assert {:ok, _t, default_exp} = CacheJWT.generate_and_sign(request(%{expires_in: 0}))
      assert_in_delta default_exp - now, 87_300, 5

      # Anything above the maximum is clamped to 24h + 15m.
      assert {:ok, _t, capped_exp} =
               CacheJWT.generate_and_sign(request(%{expires_in: 10_000_000}))

      assert_in_delta capped_exp - now, 87_300, 5
    end

    test "honors a shorter explicitly requested TTL (e.g. debug jobs)" do
      now = Joken.current_time()

      assert {:ok, _t, exp} = CacheJWT.generate_and_sign(request(%{expires_in: 4_200}))
      assert_in_delta exp - now, 4_200, 5
    end
  end
end
