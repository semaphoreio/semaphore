defmodule FrontWeb.SidebarControllerTest do
  use FrontWeb.ConnCase

  setup do
    Cacheman.clear(:front)
    Support.FakeServices.stub_responses()
  end

  describe "POST star" do
    test "returns 200" do
      conn =
        build_conn()
        |> put_req_header("x-semaphore-user-id", "78114608-be8a-465a-b9cd-81970fb802c5")
        |> put_req_header("x-semaphore-org-id", "78114608-be8a-465a-b9cd-81970fb802c5")
        |> post("https://semaphore.semaphoreci.com/sidebar/star",
          favorite_id: "1",
          kind: "project"
        )

      assert conn.status == 200
    end
  end

  describe "POST unstar" do
    test "returns 200" do
      conn =
        build_conn()
        |> put_req_header("x-semaphore-user-id", "78114608-be8a-465a-b9cd-81970fb802c5")
        |> put_req_header("x-semaphore-org-id", "78114608-be8a-465a-b9cd-81970fb802c5")
        |> post("https://semaphore.semaphoreci.com/sidebar/unstar",
          favorite_id: "1",
          kind: "project"
        )

      assert conn.status == 200
    end
  end
end
