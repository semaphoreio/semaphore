defmodule PipelinesAPI.DeploymentTargetsClient.RequestFormatter.Test do
  use ExUnit.Case
  use Plug.Test

  alias Support.Stubs.Secret

  alias PipelinesAPI.Validator
  alias PipelinesAPI.DeploymentTargetsClient.RequestFormatter

  alias InternalApi.Gofer.DeploymentTargets.{
    ListRequest,
    UpdateRequest,
    DeleteRequest,
    DescribeRequest,
    HistoryRequest,
    CordonRequest
  }

  @default_org_id "92be62c2-9cf4-4dad-b168-d6efa6aa5e21"
  @default_project_id "92be1234-1234-4234-8234-123456789012"

  setup do
    Support.Stubs.DB.reset()

    Support.Stubs.Feature.seed()
    Support.Stubs.RBAC.seed_data()
    Support.Stubs.build_shared_factories()

    on_exit(fn ->
      Support.Stubs.reset()
    end)

    {:ok,
     extra_args: %{
       "organization_id" => @default_org_id,
       "project_id" => @default_project_id,
       "requester_id" => UUID.uuid4()
     }}
  end

  describe "request formatter test" do
    test "form_list_request() returns {:ok, request} when called with map with all params" do
      project_id = UUID.uuid4()
      params = %{"project_id" => project_id}

      assert {:ok, request} = RequestFormatter.form_list_request(params)
      assert %ListRequest{project_id: ^project_id} = request
    end

    test "form_create_request() returns {:ok, request} when called with valid parameters", _ctx do
      conn = create_conn()

      assert {:ok, request} = RequestFormatter.form_create_request(conn.params, conn)

      assert request.requester_id == "9ebfd270-c6d3-413e-9faa-477fbd491077"
      assert request.target.name == "Staging"
      assert request.secret.key_id == Secret.Keys.get_key().key_id
      assert length(request.target.object_rules) == 2
      assert length(request.target.subject_rules) == 2
      assert request.target.organization_id == @default_org_id
      assert request.target.project_id == @default_project_id
    end

    test "form_update_request() returns {:ok, request} when called with valid parameters", _ctx do
      target_id = UUID.uuid4()
      conn = update_conn(target_id)

      assert {:ok, request = %UpdateRequest{}} =
               RequestFormatter.form_update_request(conn.params, conn)

      {:ok, %{env_vars: env_vars, files: files}} = Secret.Keys.decrypt(request.secret)

      env_vars = env_vars |> Enum.into([], &Util.Proto.to_map!(&1))
      files = files |> Enum.into([], &Util.Proto.to_map!(&1))

      assert env_vars == [
               %{name: "OLDVAR", value: "OLDVALUE"},
               %{name: "OLDVAR2", value: "NEWVALUE2"},
               %{name: "VAR", value: "VALUE"}
             ]

      assert files == [
               %{path: "FILE", content: "Q09OVEVOVA=="},
               %{path: "OLDFILE", content: "OLDCONTENT"},
               %{path: "OLDFILE2", content: "NEWCONTENT2"}
             ]

      assert request.requester_id == "9ebfd270-c6d3-413e-9faa-477fbd491077"
      assert request.target.name == "Staging"
      assert request.secret.key_id == Secret.Keys.get_key().key_id
      assert length(request.target.object_rules) == 2
      assert length(request.target.subject_rules) == 2
      assert request.target.organization_id == @default_org_id
      assert request.target.project_id == @default_project_id
    end

    test "form_delete_request() returns {:ok, request} when called with valid parameters" do
      target_id = "ee1d866a-d032-450d-be24-50b8a6f50ef7"
      conn = delete_conn(target_id)

      params = %{
        "target_id" => target_id,
        "requester_id" => "9ebfd270-c6d3-413e-9faa-477fbd491077",
        "unique_token" => "75c7a742-34d9-4bb4-bedc-406951f807e7"
      }

      assert {:ok, request} = RequestFormatter.form_delete_request(params, conn)
      assert %DeleteRequest{target_id: ^target_id} = request
    end

    test "form_describe_request() returns {:ok, request} when called with valid parameters" do
      project_id = UUID.uuid4()
      target_name = "myTarget"

      params = %{
        "project_id" => project_id,
        "target_name" => target_name
      }

      assert {:ok, request} = RequestFormatter.form_describe_request(params)
      assert %DescribeRequest{project_id: ^project_id, target_name: ^target_name} = request
    end

    test "form_history_request() returns {:ok, request} when called with valid parameters" do
      target_id = "ee1d866a-d032-450d-be24-50b8a6f50ef7"

      params = %{
        "target_id" => target_id,
        "cursor_type" => 0,
        "cursor_value" => 100,
        "git_ref_type" => "refType",
        "git_ref_label" => "refLabel",
        "triggered_by" => "user",
        "parameter1" => "p1",
        "parameter2" => "p2",
        "parameter3" => "p3"
      }

      assert {:ok, request} = RequestFormatter.form_history_request(params)

      assert %HistoryRequest{
               target_id: ^target_id,
               cursor_type: 0,
               cursor_value: 100,
               filters: %{
                 git_ref_type: "refType",
                 git_ref_label: "refLabel",
                 triggered_by: "user",
                 parameter1: "p1",
                 parameter2: "p2",
                 parameter3: "p3"
               }
             } = request
    end

    test "form_cordon_request() returns {:ok, request} when called with valid parameters" do
      target_id = "ee1d866a-d032-450d-be24-50b8a6f50ef7"

      params = %{
        "target_id" => target_id,
        "cordoned" => true
      }

      assert {:ok, request} = RequestFormatter.form_cordon_request(params)

      assert %CordonRequest{
               target_id: ^target_id,
               cordoned: true
             } = request
    end

    test "form_cordon_request() returns {:ok, request} when called with valid parameters 2" do
      target_id = "ee1d866a-d032-450d-be24-50b8a6f50ef7"

      params = %{
        "target_id" => target_id,
        "cordoned" => false
      }

      assert {:ok, request} = RequestFormatter.form_cordon_request(params)

      assert %CordonRequest{
               target_id: ^target_id,
               cordoned: false
             } = request
    end
  end

  describe "internal methods of request formatter " do
    test "convert_keys_to_atoms returns transformed object where string keys are replaced to atoms" do
      value_before = [
        %{"a" => %{:b => [%{"c" => %{"d" => "1", :e => 3}}]}},
        %{"b" => [1, 2, %{"c" => 1}]}
      ]

      assert [
               %{a: %{b: [%{c: %{d: "1", e: 3}}]}},
               %{b: [1, 2, %{c: 1}]}
             ] = RequestFormatter.convert_keys_to_atoms(value_before)
    end
  end

  defp create_conn() do
    init_create_conn()
    |> put_req_header("x-semaphore-user-id", "9ebfd270-c6d3-413e-9faa-477fbd491077")
    |> put_req_header("x-semaphore-org-id", @default_org_id)
  end

  defp update_conn(id) do
    init_update_conn(id)
    |> put_req_header("x-semaphore-user-id", "9ebfd270-c6d3-413e-9faa-477fbd491077")
    |> put_req_header("x-semaphore-org-id", @default_org_id)
  end

  defp init_create_conn() do
    with %{key_id: key_id, public_key: public_key} <- Secret.Keys.get_key(),
         {:ok, der_encoded} <- ExPublicKey.RSAPublicKey.encode_der(public_key),
         key <- Base.encode64(der_encoded) do
      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      json_payload = %{
        "unique_token" => UUID.uuid4(),
        "env_vars" => [%{"name" => "VAR", "value" => "VALUE"}],
        "files" => [%{"content" => "Q09OVEVOVA==", "path" => "FILE"}],
        "key" => %{
          id: key_id,
          key: key
        },
        "description" => "Staging environment",
        "name" => "Staging",
        "object_rules" => [
          %{"match_mode" => "ALL", "pattern" => "", "type" => "PR"},
          %{"match_mode" => 0, "pattern" => "", "type" => 1}
        ],
        "organization_id" => @default_org_id,
        "subject_rules" => [
          %{"subject_id" => subject_id, "type" => "USER"},
          %{"subject_id" => "admin", "type" => "role"}
        ],
        "url" => "https://staging.rtx.com",
        "project_id" => @default_project_id,
        "state" => "USABLE"
      }

      conn(:post, "/deployment_targets", Poison.encode!(json_payload))
      |> put_req_header("content-type", "application/json")
      |> parse()
    end
  end

  defp init_update_conn(target_id) do
    with %{key_id: key_id, public_key: public_key} <- Secret.Keys.get_key(),
         {:ok, der_encoded} <- ExPublicKey.RSAPublicKey.encode_der(public_key),
         key <- Base.encode64(der_encoded) do
      assert %{subject_id: subject_id} =
               Support.Stubs.DB.find_by(:subject_role_bindings, :project_id, @default_project_id)

      json_payload = %{
        "target_id" => target_id,
        "unique_token" => UUID.uuid4(),
        "env_vars" => [
          %{"name" => "VAR", "value" => "VALUE"},
          %{
            "name" => "OLDVAR",
            "value" => Validator.hide_secret("OLDVALUE")
          },
          %{"name" => "OLDVAR2", "value" => "NEWVALUE2"}
        ],
        "files" => [
          %{"content" => "Q09OVEVOVA==", "path" => "FILE"},
          %{
            "content" => Validator.hide_secret("OLDCONTENT"),
            "path" => "OLDFILE"
          },
          %{"content" => "NEWCONTENT2", "path" => "OLDFILE2"}
        ],
        "old_env_vars" => [
          %{name: "OLDVAR", value: "OLDVALUE"},
          %{name: "OLDVAR2", value: "OLDVALUE2"},
          %{name: "OLDVAR3", value: "OLDVALUE3"}
        ],
        "old_files" => [
          %{content: "OLDCONTENT", path: "OLDFILE"},
          %{content: "OLDCONTENT2", path: "OLDFILE2"}
        ],
        "key" => %{
          id: key_id,
          key: key
        },
        "id" => target_id,
        "description" => "Staging environment",
        "name" => "Staging",
        "object_rules" => [
          %{"match_mode" => 0, "pattern" => "", "type" => 0},
          %{"match_mode" => 0, "pattern" => "", "type" => 1}
        ],
        "organization_id" => @default_org_id,
        "subject_rules" => [
          %{"subject_id" => subject_id, "type" => "USER"},
          %{"subject_id" => "contributor", "type" => "role"}
        ],
        "url" => "https://staging.rtx.com",
        "project_id" => @default_project_id,
        "old_target" => %{
          description: "Old environment",
          name: "Old name"
        }
      }

      conn(:patch, "/deployment_targets/" <> target_id, Poison.encode!(json_payload))
      |> put_req_header("content-type", "application/json")
      |> parse()
    end
  end

  defp delete_conn(id) do
    json_payload = %{
      "unique_token" => UUID.uuid4()
    }

    conn(:delete, "/deployment_targets/" <> id, Poison.encode!(json_payload))
    |> put_req_header("content-type", "application/json")
    |> parse()
  end

  defp parse(conn) do
    opts = [
      pass: ["application/json"],
      json_decoder: Poison,
      parsers: [Plug.Parsers.JSON]
    ]

    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end
end
