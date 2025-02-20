defmodule PipelinesAPI.SecretClient.Test do
  use Plug.Test
  use ExUnit.Case

  alias PipelinesAPI.DeploymentsClient
  alias PipelinesAPI.SecretClient

  setup do
    Support.Stubs.reset()

    on_exit(fn ->
      Support.Stubs.reset()
    end)

    {:ok,
     extra_args: %{
       "organization_id" => UUID.uuid4(),
       "project_id" => UUID.uuid4(),
       "requester_id" => UUID.uuid4()
     }}
  end

  describe "key" do
    test "should return key" do
      {result, %{id: id, key: public_key}} = SecretClient.key()

      assert :ok == result
      assert String.length(id) > 0
      assert String.length(public_key) > 0
    end
  end

  describe "describe" do
    test "should empty secrets for target without secrets", ctx do
      conn = create_conn(ctx)
      target_id = "target1"

      assert {:ok, %{env_vars: [], files: []}} =
               SecretClient.describe(%{"target_id" => target_id}, conn)
    end

    test "should return empty secrets for target without secrets", ctx do
      conn = create_conn(ctx)
      target_id = "target1"

      assert {:ok, %{env_vars: [], files: []}} = SecretClient.describe(%{"id" => target_id}, conn)
    end

    test "should return error for request without user/organization header", _ctx do
      conn = conn(:post, "/deployments")
      target_id = "target1"

      assert {:error, %{message: _}} = SecretClient.describe(%{"target_id" => target_id}, conn)
    end

    test "should return secrets for target with secrets", ctx do
      conn = create_conn(ctx)

      target_params =
        Map.merge(
          %{
            "id" => UUID.uuid4(),
            "name" => "Staging",
            "description" => "Staging environment",
            "url" => "https://staging.rtx.com",
            "subject_rules" => [
              %{"type" => 0, "subject_id" => UUID.uuid4()},
              %{"type" => 1, "subject_id" => UUID.uuid4()}
            ],
            "object_rules" => [
              %{"type" => 0, "match_mode" => 0, "pattern" => ""},
              %{"type" => 1, "match_mode" => 0, "pattern" => ""}
            ],
            "project_id" => ctx.extra_args["project_id"]
          },
          ctx.extra_args
        )

      {:ok, key} = SecretClient.key()
      env_vars = [%{"name" => "VAR", "value" => "VALUE"}]
      files = [%{"path" => "FILE", "content" => Base.encode64("CONTENT")}]

      params =
        target_params
        |> Map.merge(%{
          "requester_id" => target_params["requester_id"],
          "env_vars" => env_vars,
          "files" => files,
          "key" => key,
          "unique_token" => UUID.uuid4()
        })

      expected_env_vars = [%{name: "VAR", value: "VALUE"}]
      expected_files = [%{path: "FILE", content: Base.encode64("CONTENT")}]

      assert {:ok, target} = DeploymentsClient.create(params, conn)

      assert {:ok, %{env_vars: ^expected_env_vars, files: ^expected_files}} =
               SecretClient.describe(%{"target_id" => target.id}, conn)
    end
  end

  defp create_conn(ctx) do
    init_conn()
    |> put_req_header("x-semaphore-user-id", ctx.extra_args["requester_id"])
    |> put_req_header("x-semaphore-org-id", ctx.extra_args["organization_id"])
  end

  defp init_conn() do
    conn(:post, "/deployments")
  end
end
