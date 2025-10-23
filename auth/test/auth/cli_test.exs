defmodule Auth.CliTest do
  use ExUnit.Case

  import Plug.Test
  import Plug.Conn

  describe ".is_call_from_deprecated_cli?" do
    test "no user agent => returns false" do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")

      refute Auth.Cli.is_call_from_deprecated_cli?(conn)
    end

    test "SemaphoreCLI user agent with a fresh version => returns false" do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")
      conn = conn |> put_req_header("user-agent", "SemaphoreCLI/v0.30.0 (...)")

      refute Auth.Cli.is_call_from_deprecated_cli?(conn)
    end

    test "SemaphoreCLI user agent with an old version" do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")
      conn = conn |> put_req_header("user-agent", "SemaphoreCLI/v0.24.0 (...)")

      assert Auth.Cli.is_call_from_deprecated_cli?(conn)
    end

    test "request to the API with a golang request" do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")
      conn = conn |> put_req_header("user-agent", "Go-http-client/2.0")

      refute Auth.Cli.is_call_from_deprecated_cli?(conn)
    end
  end

  describe ".reject_cli_client" do
    test "returns 400" do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")
      conn = Auth.Cli.reject_cli_client(conn)

      assert conn.status == 400

      assert conn.resp_body ==
               Enum.join(
                 [
                   "{\"message\": \"Call rejected because the client is outdated. ",
                   "To continue, upgrade Semaphore CLI with 'curl ",
                   "https://storage.googleapis.com/sem-cli-releases/get.sh | bash'.\"}"
                 ],
                 ""
               )
    end
  end

  describe ".is_sem_cli?" do
    setup do
      conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/jobs")
      conn = conn |> put_req_header("user-agent", "")

      {:ok, conn: conn}
    end

    test "is_sem_cli? returns false without SemaphoreCLI user-agent", %{conn: conn} do
      refute Auth.Cli.is_sem_cli?(conn)
    end

    test "is_sem_cli? returns true with SemaphoreCLI user-agent", %{conn: conn} do
      conn = put_req_header(conn, "user-agent", "SemaphoreCLI/v0.25.0 (...)")
      assert Auth.Cli.is_sem_cli?(conn)
    end

    test "is_sem_cli? returns false with Go user-agent", %{conn: conn} do
      conn = put_req_header(conn, "user-agent", "Go-http-client/2.0")
      refute Auth.Cli.is_sem_cli?(conn)
    end
  end
end
