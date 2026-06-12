defmodule PipelinesAPI.ServiceAccountClient.RequestFormatter.Test do
  use ExUnit.Case

  alias PipelinesAPI.ServiceAccountClient.RequestFormatter

  @org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @sa_id "7d111358-3b35-4836-ab23-60e043b5edab"

  defp conn_with_org do
    Plug.Test.conn(:post, "/service_accounts")
    |> Plug.Conn.put_req_header("x-semaphore-org-id", @org_id)
  end

  describe "org_id is taken from the request header" do
    test "form_describe_request/2" do
      {:ok, request} = RequestFormatter.form_describe_request(%{"id" => @sa_id}, conn_with_org())

      assert request.service_account_id == @sa_id
      assert request.org_id == @org_id
    end

    test "form_update_request/2" do
      {:ok, request} =
        RequestFormatter.form_update_request(
          %{"id" => @sa_id, "name" => "new-name", "description" => "desc"},
          conn_with_org()
        )

      assert request.service_account_id == @sa_id
      assert request.name == "new-name"
      assert request.description == "desc"
      assert request.org_id == @org_id
    end

    test "form_destroy_request/2" do
      {:ok, request} = RequestFormatter.form_destroy_request(%{"id" => @sa_id}, conn_with_org())

      assert request.service_account_id == @sa_id
      assert request.org_id == @org_id
    end

    test "form_deactivate_request/2" do
      {:ok, request} =
        RequestFormatter.form_deactivate_request(%{"id" => @sa_id}, conn_with_org())

      assert request.service_account_id == @sa_id
      assert request.org_id == @org_id
    end

    test "form_reactivate_request/2" do
      {:ok, request} =
        RequestFormatter.form_reactivate_request(%{"id" => @sa_id}, conn_with_org())

      assert request.service_account_id == @sa_id
      assert request.org_id == @org_id
    end

    test "form_regenerate_token_request/2" do
      {:ok, request} =
        RequestFormatter.form_regenerate_token_request(%{"id" => @sa_id}, conn_with_org())

      assert request.service_account_id == @sa_id
      assert request.org_id == @org_id
    end
  end
end
