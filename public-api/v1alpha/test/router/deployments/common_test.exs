defmodule Router.Deployments.CommonTest do
  use ExUnit.Case

  use Plug.Test

  alias PipelinesAPI.Deployments.Common
  alias Support.Stubs.Secret.Keys, as: StubKeys

  setup do
    Support.Stubs.reset()
    Support.Stubs.build_shared_factories()
    Support.Stubs.Feature.enable_feature("test-org", :deployment_targets)
    Support.Stubs.Feature.enable_feature("test-org", :advanced_deployment_targets)

    on_exit(fn ->
      Support.Stubs.reset()
    end)

    {:ok, %{org_id: "test-org"}}
  end

  describe "Secrets.encrypt_data/1" do
    test "when key is valid then encrypts data" do
      %{key_id: key_id, public_key: public_key} = StubKeys.get_key()

      secret_data = %{
        env_vars: [%{name: "ENV_VAR", value: "VALUE"}],
        files: [%{path: "PATH", content: "CONTENT"}]
      }

      assert {:ok, encrypted_data} = Common.encrypt_data(secret_data, {key_id, public_key})
      assert {:ok, decrypted_data} = StubKeys.decrypt(encrypted_data)
      assert ^secret_data = Util.Proto.to_map!(decrypted_data)
    end

    test "when key is corrupted then returns error" do
      setup_corrupted_key()
      %{key_id: key_id, public_key: public_key} = StubKeys.get_key()

      secret_data = %{
        env_vars: [%{name: "ENV_VAR", value: "VALUE"}],
        files: [%{path: "PATH", content: "CONTENT"}]
      }

      assert {:error, "Encryption failed"} =
               Common.encrypt_data(secret_data, {key_id, public_key})
    end
  end

  describe "tests has_deployment_targets_enabled" do
    test "check that deployment targets is enabled for organization", ctx do
      conn = get_conn(ctx)
      conn = Common.has_deployment_targets_enabled(conn, nil)
      assert conn.status == nil
    end

    test "check that deployment targets is not enabled for organization", ctx do
      conn = get_conn(ctx) |> put_req_header("x-semaphore-org-id", "fakeOrg")
      conn = Common.has_deployment_targets_enabled(conn, nil)
      assert conn.status == 403
    end
  end

  describe "is_list_of_subject_rules/1" do
    test "when subject rules is nil then returns true" do
      assert Common.is_list_of_subject_rules(nil)
    end

    test "when subject rules is a list of maps with type then returns true" do
      assert Common.is_list_of_subject_rules([%{"type" => "USER"}])
    end

    test "when subject rules is invalid then returns false" do
      refute Common.is_list_of_subject_rules(%{"type" => "USER"})
      refute Common.is_list_of_subject_rules([%{"foo" => "bar"}])
      refute Common.is_list_of_subject_rules([%{"type" => "USER"}, %{"foo" => "bar"}])
      refute Common.is_list_of_subject_rules("type => USER")
    end
  end

  describe "is_list_of_object_rules/1" do
    test "when object rules is nil then returns true" do
      assert Common.is_list_of_object_rules(nil)
    end

    test "when object rules is a list of maps with type then returns true" do
      assert Common.is_list_of_object_rules([
               %{"type" => "BRANCH", "match_mode" => "EXACT", "pattern" => "master"}
             ])
    end

    test "when object rules is invalid then returns false" do
      refute Common.is_list_of_object_rules(%{
               "type" => "BRANCH",
               "match_mode" => "EXACT",
               "pattern" => "master"
             })

      refute Common.is_list_of_object_rules([%{"foo" => "bar"}])

      refute Common.is_list_of_object_rules([
               %{"type" => "BRANCH", "match_mode" => "EXACT", "pattern" => "master"},
               %{"foo" => "bar"}
             ])

      refute Common.is_list_of_object_rules("type => USER")
    end
  end

  describe "has_deployment_targets_enabled/2" do
    setup do
      Support.Stubs.Feature.enable_feature("test-org-1", :deployment_targets)
      Support.Stubs.Feature.enable_feature("test-org-2", :deployment_targets)
      Support.Stubs.Feature.enable_feature("test-org-2", :advanced_deployment_targets)

      on_exit(fn ->
        Support.Stubs.Feature.disable_feature("test-org-1", :deployment_targets)
        Support.Stubs.Feature.disable_feature("test-org-2", :deployment_targets)
        Support.Stubs.Feature.disable_feature("test-org-2", :advanced_deployment_targets)
      end)
    end

    test "when subject rules are nil then allows org without advanced" do
      assert %{status: nil} =
               Common.has_deployment_targets_enabled(
                 conn(:post, "/deployment_targets", %{})
                 |> put_req_header("x-semaphore-org-id", "test-org-1")
                 |> put_req_header("x-semaphore-user-id", "userid"),
                 nil
               )

      assert %{status: nil} =
               Common.has_deployment_targets_enabled(
                 conn(:post, "/deployment_targets", %{})
                 |> put_req_header("x-semaphore-org-id", "test-org-2")
                 |> put_req_header("x-semaphore-user-id", "userid"),
                 nil
               )
    end

    test "when subject rules contain only rules with ANY type then allows org without advanced" do
      assert %{status: nil} =
               Common.has_deployment_targets_enabled(
                 conn(:post, "/deployment_targets", %{
                   "subject_rules" => [%{"type" => "ANY"}]
                 })
                 |> put_req_header("x-semaphore-org-id", "test-org-1")
                 |> put_req_header("x-semaphore-user-id", "userid"),
                 nil
               )

      assert %{status: nil} =
               Common.has_deployment_targets_enabled(
                 conn(:post, "/deployment_targets", %{
                   "subject_rules" => [%{"type" => "ANY"}]
                 })
                 |> put_req_header("x-semaphore-org-id", "test-org-2")
                 |> put_req_header("x-semaphore-user-id", "userid"),
                 nil
               )
    end

    test "when subject rules contain rules with other types then allows org with advanced" do
      assert %{status: 403} =
               Common.has_deployment_targets_enabled(
                 conn(:post, "/deployment_targets", %{
                   "subject_rules" => [%{"type" => "USER"}, %{"type" => "ANY"}]
                 })
                 |> put_req_header("x-semaphore-org-id", "test-org-1")
                 |> put_req_header("x-semaphore-user-id", "userid"),
                 nil
               )

      assert %{status: nil} =
               Common.has_deployment_targets_enabled(
                 conn(:post, "/deployment_targets", %{
                   "subject_rules" => [%{"type" => "USER"}, %{"type" => "ANY"}]
                 })
                 |> put_req_header("x-semaphore-org-id", "test-org-2")
                 |> put_req_header("x-semaphore-user-id", "userid"),
                 nil
               )
    end
  end

  describe "tests filtering sensitive fields in params" do
    test "check that sensitive fields are removed from params", ctx do
      conn =
        get_conn(ctx)
        |> Map.put(:params, %{
          "env_vars" => [],
          "old_env_vars" => [],
          "files" => [],
          "old_files" => [],
          "old_target" => %{},
          "key" => "abc"
        })

      conn = Common.remove_sensitive_params(conn, nil)
      assert conn.params["old_env_vars"] == nil
      assert conn.params["env_vars"] == []
      assert conn.params["old_files"] == nil
      assert conn.params["files"] == []
      assert conn.params["key"] == nil
      assert conn.params["old_target"] == nil
    end
  end

  defp get_conn(ctx) do
    conn(:get, "/deployment_targets")
    |> put_req_header("x-semaphore-user-id", "userid")
    |> put_req_header("x-semaphore-org-id", ctx.org_id)
  end

  defp setup_corrupted_key do
    previous_key = StubKeys.get_key()
    corrupted_key = %{previous_key | public_key: "foo"}

    Agent.update(StubKeys, fn _ -> corrupted_key end)
    on_exit(fn -> Agent.update(StubKeys, fn _ -> previous_key end) end)
  end
end
