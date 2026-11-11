defmodule PipelinesAPI.ServiceAccountClient.RequestFormatter.Test do
  use ExUnit.Case
  use Plug.Test

  alias PipelinesAPI.ServiceAccountClient.RequestFormatter

  alias InternalApi.ServiceAccount.RegenerateTokenRequest

  # A new token is held by whoever asked for it, and what happens to the account's owner
  # follows from that. The member is the one the call is made as, never a name the
  # request body happens to carry.
  test "form_regenerate_token_request() names the member the call is made as" do
    params = %{"id" => "sa-1", "requester_id" => "somebody-else"}

    assert {:ok, request = %RegenerateTokenRequest{}} =
             RequestFormatter.form_regenerate_token_request(params, create_conn())

    assert request.service_account_id == "sa-1"
    assert request.org_id == "test_org"
    assert request.requester_id == "test_user"
  end

  test "form_regenerate_token_request() returns internal error when not called with a map" do
    assert {:error, {:internal, "Internal error"}} ==
             RequestFormatter.form_regenerate_token_request(nil, create_conn())
  end

  defp create_conn do
    conn(:post, "/service_accounts/sa-1/regenerate_token")
    |> put_req_header("x-semaphore-user-id", "test_user")
    |> put_req_header("x-semaphore-org-id", "test_org")
  end
end
