defmodule Zebra.Workers.JobRequestFactory.CephStsTest do
  use ExUnit.Case, async: false

  alias Zebra.Workers.JobRequestFactory.CephSts

  defmodule SignerMock do
    def sign_v4(_ak, _sk, _region, _service, _time, _method, _url, headers, _body) do
      send(self(), {:sign_called, headers})
      [{"authorization", "AWS4-HMAC-SHA256 test"} | headers]
    end
  end

  defmodule HttpClientSuccessMock do
    def request(:post, _request, _opts, _http_opts) do
      body = """
      <AssumeRoleResponse>
        <AssumeRoleResult>
          <Credentials>
            <AccessKeyId>TMP_ACCESS</AccessKeyId>
            <SecretAccessKey>TMP_SECRET</SecretAccessKey>
            <SessionToken>TMP_TOKEN</SessionToken>
          </Credentials>
        </AssumeRoleResult>
      </AssumeRoleResponse>
      """

      {:ok, {{'HTTP/1.1', 200, 'OK'}, [], body}}
    end
  end

  defmodule HttpClientErrorMock do
    def request(:post, _request, _opts, _http_opts) do
      body = """
      <ErrorResponse>
        <Error>
          <Code>AccessDenied</Code>
          <Message>Denied</Message>
        </Error>
      </ErrorResponse>
      """

      {:ok, {{'HTTP/1.1', 403, 'Forbidden'}, [], body}}
    end
  end

  setup do
    System.put_env("CEPH_ENDPOINT", "https://ceph.example.com")
    System.put_env("CEPH_ZEBRA_ACCESS_KEY", "zebra-ak")
    System.put_env("CEPH_ZEBRA_SECRET_KEY", "zebra-sk")

    Application.put_env(:zebra, :ceph_sts_signer_module, SignerMock)

    on_exit(fn ->
      System.delete_env("CEPH_ENDPOINT")
      System.delete_env("CEPH_ZEBRA_ACCESS_KEY")
      System.delete_env("CEPH_ZEBRA_SECRET_KEY")
      Application.delete_env(:zebra, :ceph_sts_signer_module)
      Application.delete_env(:zebra, :ceph_sts_http_client_module)
    end)

    :ok
  end

  test "assume_role returns temporary credentials on success" do
    Application.put_env(:zebra, :ceph_sts_http_client_module, HttpClientSuccessMock)

    assert {:ok,
            %{
              access_key_id: "TMP_ACCESS",
              secret_access_key: "TMP_SECRET",
              session_token: "TMP_TOKEN"
            }} = CephSts.assume_role("arn:aws:iam::acc:role/project-rw", "zebra-rw-job", 3600)

    assert_receive {:sign_called, headers}
    assert Enum.any?(headers, fn {name, _} -> name == "host" end)
  end

  test "assume_role returns sts_error when STS returns XML error" do
    Application.put_env(:zebra, :ceph_sts_http_client_module, HttpClientErrorMock)

    assert {:error, {:sts_error, "AccessDenied", "Denied"}} =
             CephSts.assume_role("arn:aws:iam::acc:role/project-rw", "zebra-rw-job", 3600)
  end

  test "assume_role returns missing_config when required env vars are absent" do
    System.delete_env("CEPH_ZEBRA_SECRET_KEY")
    Application.put_env(:zebra, :ceph_sts_http_client_module, HttpClientSuccessMock)

    assert {:error, {:missing_config, missing}} =
             CephSts.assume_role("arn:aws:iam::acc:role/project-rw", "zebra-rw-job", 3600)

    assert "CEPH_ZEBRA_SECRET_KEY" in missing
  end
end
