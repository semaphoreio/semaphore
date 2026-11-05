defmodule FrontWeb.DesignBookControllerTest do
  use FrontWeb.ConnCase

  describe "GET /design-book" do
    test "renders the mount point for the playground app", %{conn: conn} do
      conn = get(conn, "/design-book")

      body = html_response(conn, 200)

      assert body =~ ~s(id="design-book-root")
      assert body =~ "/projects/assets/design_book.js"
    end
  end

  describe "GET /design-book/data/workspace/:workflow_id" do
    test "returns the contract fixture", %{conn: conn} do
      conn = get(conn, "/design-book/data/workspace/demo")

      payload = json_response(conn, 200)

      assert Enum.sort(Map.keys(payload)) == ["attempts", "current", "workflow"]
    end

    test "returns four attempts, the last one passing", %{conn: conn} do
      conn = get(conn, "/design-book/data/workspace/demo")

      attempts = json_response(conn, 200)["attempts"]

      assert length(attempts) == 4
      assert Enum.map(attempts, & &1["index"]) == [1, 2, 3, 4]
      assert Enum.map(attempts, & &1["result"]) == ["failed", "failed", "failed", "passed"]
    end

    test "returns five dependency-linked blocks and one promotion", %{conn: conn} do
      conn = get(conn, "/design-book/data/workspace/demo")

      current = json_response(conn, 200)["current"]

      assert length(current["blocks"]) == 5

      assert Enum.map(current["blocks"], & &1["name"]) == [
               "Setup",
               "Unit tests",
               "Integration tests",
               "E2E tests",
               "Packaging"
             ]

      assert Enum.map(current["promotions"], & &1["name"]) == ["Deploy to staging"]
    end

    test "returns reused, copied and freshly executed jobs", %{conn: conn} do
      conn = get(conn, "/design-book/data/workspace/demo")

      blocks = json_response(conn, 200)["current"]["blocks"]
      jobs = Enum.flat_map(blocks, & &1["jobs"])

      reused_block = Enum.find(blocks, & &1["reused_from"])

      assert reused_block["name"] == "Setup"
      assert Enum.any?(jobs, &(&1["original_job_id"] && &1["executed_in_attempt"] == 2))
      assert Enum.any?(jobs, &(is_nil(&1["original_job_id"]) && &1["executed_in_attempt"] == 4))
    end
  end
end
