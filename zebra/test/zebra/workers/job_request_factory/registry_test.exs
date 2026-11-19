defmodule Zebra.Workers.JobRequestFactory.RegistryTest do
  use Zebra.DataCase

  import ExUnit.CaptureLog

  alias Zebra.Workers.JobRequestFactory.Registry
  alias InternalApi.ResponseStatus

  @org_id Ecto.UUID.generate()
  @host "registry.example.com"
  @password "registry-password"

  describe ".find" do
    test "asks cachehub for the organization's credentials with the given validity" do
      test_pid = self()

      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn req, _ ->
        send(test_pid, {:get_credentials, req})
        credentials()
      end)

      assert {:ok, credentials} = Registry.find(@org_id, nil, 7_200)
      assert credentials == credentials()

      assert_received {:get_credentials, req}
      assert req.organization_id == @org_id
      assert req.min_validity_seconds == 7_200
      assert req.job_id == ""
      assert req.refresh_validity_seconds == 0
    end

    test "asks for a refresh grant for the job when given one" do
      test_pid = self()
      job_id = Ecto.UUID.generate()
      project_id = Ecto.UUID.generate()

      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn req, _ ->
        send(test_pid, {:get_credentials, req})
        credentials()
      end)

      assert {:ok, _credentials} =
               Registry.find(@org_id, nil, 7_200,
                 job_id: job_id,
                 project_id: project_id,
                 validity_seconds: 9_000
               )

      assert_received {:get_credentials, req}
      assert req.job_id == job_id
      assert req.project_id == project_id
      assert req.refresh_validity_seconds == 9_000
    end

    test "logs a warning and returns {:ok, nil} on a non-OK status" do
      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn _, _ ->
        %{credentials() | status: ResponseStatus.new(code: ResponseStatus.Code.value(:BAD_PARAM))}
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Registry.find(@org_id, nil, 7_200)
        end)

      assert log =~ "non-OK status for registry credentials"
      assert log =~ @org_id
      refute log =~ @password
    end

    test "logs a warning and returns {:ok, nil} when a credential is blank" do
      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn _, _ ->
        %{credentials() | password: ""}
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Registry.find(@org_id, nil, 7_200)
        end)

      assert log =~ "incomplete registry credentials"
    end

    test "logs a warning and returns {:ok, nil} when cachehub raises" do
      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn _, _ ->
        raise "boom"
      end)

      log =
        capture_log(fn ->
          assert {:ok, nil} = Registry.find(@org_id, nil, 7_200)
        end)

      assert log =~ "Failed to fetch registry credentials from cachehub"
      assert log =~ @org_id
    end

    test "forked PR gets no credentials, even when approved to use the cache" do
      test_pid = self()

      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn _, _ ->
        send(test_pid, :get_credentials_called)
        raise "cachehub should not be asked for registry credentials"
      end)

      repo = %{pr_slug: "contributor/repo", repo_slug: "org/repo", approval_enable_cache: true}

      assert {:ok, nil} = Registry.find(@org_id, repo, 7_200)
      refute_received :get_credentials_called
    end

    test "a pull request from the same repository gets credentials" do
      GrpcMock.stub(Support.FakeServers.RegistryApi, :get_credentials, fn _, _ ->
        credentials()
      end)

      repo = %{pr_slug: "org/repo", repo_slug: "org/repo"}

      assert {:ok, credentials} = Registry.find(@org_id, repo, 7_200)
      assert credentials == credentials()
    end
  end

  describe ".env_vars" do
    test "no credentials => no variables" do
      assert Registry.env_vars(nil, []) == {:ok, []}
    end

    test "host, the organization's URL, username and password" do
      assert Registry.env_vars(credentials(), ["A"]) ==
               {:ok,
                [
                  %{"name" => "SEMAPHORE_REGISTRY_HOST", "value" => Base.encode64(@host)},
                  %{
                    "name" => "SEMAPHORE_REGISTRY_URL",
                    "value" => Base.encode64("#{@host}/orgs/#{@org_id}")
                  },
                  %{"name" => "SEMAPHORE_REGISTRY_USERNAME", "value" => Base.encode64("AWS")},
                  %{"name" => "SEMAPHORE_REGISTRY_PASSWORD", "value" => Base.encode64(@password)},
                  %{
                    "name" => "SEMAPHORE_REGISTRY_EXPIRES_AT",
                    "value" => Base.encode64("1800000000")
                  }
                ]}
    end

    test "a refresh grant comes with its URL when the job API is configured" do
      credentials = %{credentials() | refresh_token: "grant"}
      names = fn {:ok, vars} -> Enum.map(vars, & &1["name"]) end

      refute "SEMAPHORE_REGISTRY_REFRESH_TOKEN" in names.(Registry.env_vars(credentials, []))

      for url <- ["http://cachehub.example.com", "cachehub.example.com", "https://", " "] do
        Application.put_env(:zebra, :cachehub_job_api_url, url)
        refute "SEMAPHORE_REGISTRY_REFRESH_TOKEN" in names.(Registry.env_vars(credentials, []))
      end

      Application.put_env(:zebra, :cachehub_job_api_url, "https://cachehub.example.com")
      on_exit(fn -> Application.delete_env(:zebra, :cachehub_job_api_url) end)

      {:ok, vars} = Registry.env_vars(credentials, [])
      values = Map.new(vars, &{&1["name"], Base.decode64!(&1["value"])})

      assert values["SEMAPHORE_REGISTRY_REFRESH_TOKEN"] == "grant"

      assert values["SEMAPHORE_REGISTRY_REFRESH_URL"] ==
               "https://cachehub.example.com/api/v1/credentials/registry"

      refute "SEMAPHORE_REGISTRY_REFRESH_TOKEN" in names.(Registry.env_vars(credentials(), []))
    end

    test "sets none when the job sets a SEMAPHORE_REGISTRY_* variable itself" do
      assert Registry.env_vars(credentials(), ["SEMAPHORE_REGISTRY_URL"]) == {:ok, []}
      assert Registry.env_vars(credentials(), ["semaphore_registry_password"]) == {:ok, []}
    end

    test "variables of other groups do not count" do
      assert {:ok, [_, _, _, _, _]} =
               Registry.env_vars(credentials(), ["SEMAPHORE_CACHE_S3_BUCKET", "DOCKER_HOST"])
    end
  end

  defp credentials do
    InternalApi.Registry.GetCredentialsResponse.new(
      status: ResponseStatus.new(code: ResponseStatus.Code.value(:OK)),
      host: @host,
      repository_prefix: "orgs/#{@org_id}",
      username: "AWS",
      password: @password,
      expires_at: Google.Protobuf.Timestamp.new(seconds: 1_800_000_000)
    )
  end
end
