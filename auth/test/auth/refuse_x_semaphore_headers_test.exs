defmodule Auth.RefuseXSemaphoreHeadersTest do
  use ExUnit.Case

  import Plug.Test
  import Plug.Conn

  test "the caller passed an x-semaphore-* header, we respond with 404" do
    assert {404, _, "Not Found"} = call_with_header("x-semaphore-user-id", "some-value")
    assert {404, _, "Not Found"} = call_with_header("x-semaphore-org-id", "some-value")
    assert {404, _, "Not Found"} = call_with_header("x-semaphore-org-username", "some-value")
    assert {404, _, "Not Found"} = call_with_header("x-semaphore-user-anonymous", "some-value")
  end

  def call_with_header(name, value) do
    conn = conn(:get, "https://org1.semaphoretest.test/exauth/api/v1alpha/secrets")
    conn = conn |> put_req_header(name, value)

    conn = Auth.call(conn, [])

    sent_resp(conn)
  end
end
