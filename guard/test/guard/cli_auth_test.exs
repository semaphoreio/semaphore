defmodule Guard.CLIAuthTest do
  use Guard.RepoCase, async: false

  import Mock

  alias Guard.CLIAuth
  alias Guard.CLIAuth.DeviceRateLimiter
  alias Guard.Store.CliAuthCode
  alias Guard.Repo
  alias Guard.McpOAuth.PKCE

  import Ecto.Query

  setup do
    DeviceRateLimiter.reset()

    user_id = Ecto.UUID.generate()
    {:ok, _} = Support.Factories.RbacUser.insert(user_id)

    {:ok, user_id: user_id}
  end

  # A fresh signup: rbac user exists, front user has no token yet.
  defp fresh_front_user(user_id) do
    {:ok, _} = Support.Factories.FrontUser.insert(id: user_id)
    :ok
  end

  # An existing account already carries a (hashed) token.
  defp existing_front_user(user_id) do
    {:ok, _} =
      %Guard.FrontRepo.User{
        id: user_id,
        email: "existing-#{user_id}@example.com",
        name: "existing",
        authentication_token: "already-a-hash"
      }
      |> Guard.FrontRepo.insert()

    :ok
  end

  defp device_row(device_code) do
    Repo.get_by(Guard.Repo.CliAuthCode, device_code_hash: CliAuthCode.hash(device_code))
  end

  defp expire!(row_id) do
    past = DateTime.utc_now() |> DateTime.add(-60, :second) |> DateTime.truncate(:second)

    from(r in Guard.Repo.CliAuthCode, where: r.id == ^row_id)
    |> Repo.update_all(set: [expires_at: past])
  end

  defp set_last_polled!(row_id, seconds_ago) do
    past = DateTime.utc_now() |> DateTime.add(-seconds_ago, :second) |> DateTime.truncate(:second)

    from(r in Guard.Repo.CliAuthCode, where: r.id == ^row_id)
    |> Repo.update_all(set: [last_polled_at: past])
  end

  describe "device grant — happy path (fresh signup)" do
    test "issue -> approve -> poll returns a freshly minted token", %{user_id: user_id} do
      :ok = fresh_front_user(user_id)

      assert {:ok, device} =
               CLIAuth.request_device_authorization(%{
                 ip: "203.0.113.7",
                 geo: "US",
                 user_agent: "sem-ai/1.0"
               })

      assert is_binary(device.device_code)
      assert device.user_code =~ ~r/^[BCDFGHJKLMNPQRSTVWXZ]{4}-[BCDFGHJKLMNPQRSTVWXZ]{4}$/
      assert device.expires_in == 900
      assert device.interval == 5
      assert device.verification_uri =~ "/device"

      row = device_row(device.device_code)
      assert row.status == "pending"
      assert is_nil(row.user_id)
      assert row.requester_ip == "203.0.113.7"

      # Still pending -> authorization_pending.
      assert {:error, :authorization_pending} = CLIAuth.poll_device_token(device.device_code)

      assert {:ok, :approved} = CLIAuth.approve_device(row.id, user_id)

      assert {:ok, token} = CLIAuth.poll_device_token(device.device_code)
      assert is_binary(token) and token != ""
    end

    test "second poll after redemption returns invalid_grant, no token (single-use)", %{
      user_id: user_id
    } do
      :ok = fresh_front_user(user_id)

      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)
      {:ok, :approved} = CLIAuth.approve_device(row.id, user_id)

      assert {:ok, _token} = CLIAuth.poll_device_token(device.device_code)
      assert {:error, :invalid_grant} = CLIAuth.poll_device_token(device.device_code)
      assert device_row(device.device_code).status == "consumed"
    end
  end

  describe "device grant — token policy" do
    test "existing account is rejected with token_exists and the row is consumed", %{
      user_id: user_id
    } do
      :ok = existing_front_user(user_id)

      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)
      {:ok, :approved} = CLIAuth.approve_device(row.id, user_id)

      assert {:error, :token_exists} = CLIAuth.poll_device_token(device.device_code)
      # No replay: the approval was burned even though no token was returned.
      assert {:error, :invalid_grant} = CLIAuth.poll_device_token(device.device_code)
    end

    test "if minting errors on persist, the device code is NOT consumed (client can retry)", %{
      user_id: user_id
    } do
      :ok = fresh_front_user(user_id)

      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)
      {:ok, :approved} = CLIAuth.approve_device(row.id, user_id)

      with_mock Guard.FrontRepo.User, [:passthrough],
        mint_token_if_absent: fn _ -> {:error, "persist failed"} end do
        assert {:error, "persist failed"} = CLIAuth.poll_device_token(device.device_code)
      end

      # Still approved, not consumed: a retry (with mint working again) succeeds.
      assert device_row(device.device_code).status == "approved"
      assert {:ok, token} = CLIAuth.poll_device_token(device.device_code)
      assert is_binary(token) and token != ""
    end

    test "two overlapping signups for the same fresh account: exactly one mints, the other is rejected",
         %{user_id: user_id} do
      :ok = fresh_front_user(user_id)

      {:ok, device_a} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      {:ok, device_b} = CLIAuth.request_device_authorization(%{ip: "203.0.113.8"})

      row_a = device_row(device_a.device_code)
      row_b = device_row(device_b.device_code)
      {:ok, :approved} = CLIAuth.approve_device(row_a.id, user_id)
      {:ok, :approved} = CLIAuth.approve_device(row_b.id, user_id)

      # Two "different CLIs" polling concurrently for the same fresh account.
      # The atomic conditional UPDATE in mint_token_if_absent/1 means exactly
      # one of these wins, regardless of interleaving — this is the crux of
      # HIGH-1: no read-then-write window where both would see no token.
      results =
        [device_a.device_code, device_b.device_code]
        |> Enum.map(fn code -> Task.async(fn -> CLIAuth.poll_device_token(code) end) end)
        |> Enum.map(&Task.await(&1, 5_000))

      assert Enum.count(results, &match?({:ok, _token}, &1)) == 1
      assert Enum.count(results, &match?({:error, :token_exists}, &1)) == 1

      # No replay on either side: both codes are consumed exactly once.
      assert device_row(device_a.device_code).status == "consumed"
      assert device_row(device_b.device_code).status == "consumed"

      # Exactly one token was persisted for the user (no last-writer-wins).
      {:ok, front_user} = Guard.Store.User.Front.find(user_id)
      assert is_binary(front_user.authentication_token)
    end
  end

  describe "device grant — terminal states" do
    test "deny -> access_denied" do
      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)

      assert {:ok, :denied} = CLIAuth.deny_device(row.id)
      assert {:error, :access_denied} = CLIAuth.poll_device_token(device.device_code)
    end

    test "expiry -> expired_token", %{user_id: _user_id} do
      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)

      expire!(row.id)
      assert {:error, :expired_token} = CLIAuth.poll_device_token(device.device_code)
    end

    test "expired even when already approved -> expired_token", %{user_id: user_id} do
      :ok = fresh_front_user(user_id)

      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)
      {:ok, :approved} = CLIAuth.approve_device(row.id, user_id)

      expire!(row.id)
      assert {:error, :expired_token} = CLIAuth.poll_device_token(device.device_code)
    end

    test "unknown device_code -> invalid_grant" do
      assert {:error, :invalid_grant} = CLIAuth.poll_device_token("no-such-device-code")
    end
  end

  describe "device grant — slow_down" do
    test "polling faster than the interval returns slow_down and bumps the interval" do
      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})

      assert {:error, :authorization_pending} = CLIAuth.poll_device_token(device.device_code)
      # Immediate re-poll is faster than the 5s interval.
      assert {:error, :slow_down} = CLIAuth.poll_device_token(device.device_code)

      assert device_row(device.device_code).interval == 10
    end

    test "a compliant client polling exactly at the interval boundary is not spuriously throttled" do
      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)

      # Default interval is 5s. Both `now` and `last_polled_at` are
      # second-truncated, so a poll that landed exactly `interval` real
      # seconds after the previous one can read back as only
      # `interval - 1` seconds apart. Without the 1s grace this used to
      # return :slow_down (and ratchet the interval up) for a fully
      # compliant client.
      set_last_polled!(row.id, row.interval - 1)

      assert {:error, :authorization_pending} = CLIAuth.poll_device_token(device.device_code)
      assert device_row(device.device_code).interval == 5
    end

    test "a poll that is genuinely too fast still gets slow_down" do
      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      row = device_row(device.device_code)

      # Well inside the throttle window even with the 1s grace applied.
      set_last_polled!(row.id, row.interval - 2)

      assert {:error, :slow_down} = CLIAuth.poll_device_token(device.device_code)
      assert device_row(device.device_code).interval == 10
    end
  end

  describe "device grant — user_code entry defenses" do
    test "a user_code is invalidated after too many entry attempts" do
      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})

      for _ <- 1..5 do
        assert {:ok, _row} = CLIAuth.verify_user_code(device.user_code)
      end

      assert {:error, :too_many_attempts} = CLIAuth.verify_user_code(device.user_code)
      assert device_row(device.device_code).status == "denied"
    end

    test "wrong user_code returns invalid_user_code" do
      assert {:error, :invalid_user_code} = CLIAuth.verify_user_code("ZZZZ-ZZZZ")
    end

    test "dashes and lowercase are accepted (normalized before compare)" do
      {:ok, device} = CLIAuth.request_device_authorization(%{ip: "203.0.113.7"})
      normalized = CliAuthCode.normalize_user_code(device.user_code)
      lower_with_dashes = String.downcase(device.user_code)

      assert {:ok, row} = CLIAuth.verify_user_code(lower_with_dashes)
      assert row.user_code_hash == CliAuthCode.hash(normalized)
    end

    test "the endpoint locks globally once the rate limit is exceeded" do
      Enum.each(1..DeviceRateLimiter.max_failures(), fn _ ->
        DeviceRateLimiter.record_failure()
      end)

      assert {:error, :rate_limited} = CLIAuth.verify_user_code("BCDF-GHJK")
    end
  end

  describe "loopback flow still works" do
    test "issue -> exchange mints the token atomically, and the code is single-use", %{
      user_id: user_id
    } do
      :ok = fresh_front_user(user_id)

      verifier = "loopback-verifier-that-is-long-enough-1234567890"
      challenge = PKCE.compute_challenge(verifier)
      redirect_uri = "http://127.0.0.1:38213/callback"

      assert {:ok, code} = CLIAuth.issue_code(user_id, challenge, redirect_uri)

      params = %{
        "code" => code,
        "code_verifier" => verifier,
        "redirect_uri" => redirect_uri
      }

      # exchange/1 now mints inside the same transaction as redemption —
      # no separate mint_token call, and no window between "code consumed"
      # and "token minted".
      assert {:ok, token} = CLIAuth.exchange(params)
      assert is_binary(token) and token != ""

      # Single-use: the second exchange fails.
      assert {:error, :invalid_grant} = CLIAuth.exchange(params)
    end

    test "existing account is rejected with token_exists and the code is still consumed", %{
      user_id: user_id
    } do
      :ok = existing_front_user(user_id)

      verifier = "loopback-verifier-that-is-long-enough-1234567890"
      challenge = PKCE.compute_challenge(verifier)
      redirect_uri = "http://127.0.0.1:38213/callback"

      {:ok, code} = CLIAuth.issue_code(user_id, challenge, redirect_uri)

      params = %{
        "code" => code,
        "code_verifier" => verifier,
        "redirect_uri" => redirect_uri
      }

      assert {:error, :token_exists} = CLIAuth.exchange(params)
      # No replay: the existing-user outcome is terminal, same as the device flow.
      assert {:error, :invalid_grant} = CLIAuth.exchange(params)
    end

    test "if minting errors on persist, the loopback code is NOT consumed (client can retry)",
         %{user_id: user_id} do
      :ok = fresh_front_user(user_id)

      verifier = "loopback-verifier-that-is-long-enough-1234567890"
      challenge = PKCE.compute_challenge(verifier)
      redirect_uri = "http://127.0.0.1:38213/callback"
      {:ok, code} = CLIAuth.issue_code(user_id, challenge, redirect_uri)

      params = %{
        "code" => code,
        "code_verifier" => verifier,
        "redirect_uri" => redirect_uri
      }

      with_mock Guard.FrontRepo.User, [:passthrough],
        mint_token_if_absent: fn _ -> {:error, "persist failed"} end do
        assert {:error, "persist failed"} = CLIAuth.exchange(params)
      end

      # Still redeemable: the failed mint did not burn the code.
      assert {:ok, token} = CLIAuth.exchange(params)
      assert is_binary(token) and token != ""
    end

    test "wrong PKCE verifier is rejected", %{user_id: user_id} do
      challenge = PKCE.compute_challenge("the-real-verifier-value-1234567890")
      redirect_uri = "http://localhost:38213/callback"
      {:ok, code} = CLIAuth.issue_code(user_id, challenge, redirect_uri)

      params = %{
        "code" => code,
        "code_verifier" => "a-different-verifier-value",
        "redirect_uri" => redirect_uri
      }

      assert {:error, :invalid_grant} = CLIAuth.exchange(params)
    end

    test "non-loopback redirect_uri is refused" do
      refute CLIAuth.loopback_redirect?("https://evil.example.com/callback")
      assert CLIAuth.loopback_redirect?("http://127.0.0.1:1234/cb")
      assert CLIAuth.loopback_redirect?("http://localhost:1234/cb")
    end
  end
end
