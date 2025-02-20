defmodule Gofer.Deployment.Model.DeploymentTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.Deployment.Model.Deployment

  setup_all do
    [
      bare_params: %{
        name: "deployment_target",
        description: "Used to encapsulate secret and restrictions for promotions",
        url: "https://www.random.com/url",
        organization_id: UUID.uuid4(),
        project_id: UUID.uuid4(),
        created_by: UUID.uuid4(),
        updated_by: UUID.uuid4(),
        unique_token: UUID.uuid4(),
        subject_rules: [],
        object_rules: []
      },
      subject_rules: [
        %{type: :USER, subject_id: UUID.uuid4()},
        %{type: :ROLE, subject_id: UUID.uuid4()},
        %{type: :AUTO, subject_id: "auto-promotion"}
      ],
      object_rules: [
        %{type: :BRANCH, match_mode: :EXACT, pattern: "master"},
        %{type: :TAG, match_mode: :REGEX, pattern: "^v[0-9]+.0.0$"}
      ]
    ]
  end

  describe "changeset/2" do
    test "with empty struct sets default status to :SYNCING", %{bare_params: params} do
      changeset = assert_valid?(&Deployment.changeset/2, params)
      deployment = Ecto.Changeset.apply_changes(changeset)
      assert %Deployment{state: :SYNCING} = deployment
    end

    test "when name is empty then invalid", %{bare_params: params} do
      changeset = assert_invalid?(&Deployment.changeset/2, %{params | name: ""})
      assert [name: {"can't be blank", [validation: :required]}] = changeset.errors
    end

    test "when name is longer than 255 characters then invalid", %{bare_params: params} do
      name = for _ <- 1..300, into: "", do: <<Enum.random('0123456789abcdef')>>
      changeset = assert_invalid?(&Deployment.changeset/2, %{params | name: name})

      assert [
               name:
                 {"should be at most %{count} character(s)",
                  [{:count, 255}, {:validation, :length}, {:kind, :max}, {:type, :string}]}
             ] = changeset.errors
    end

    test "when name is invalid then invalid", %{bare_params: params} do
      error_message = "must contain only alphanumericals, dashes, underscores or dots"

      changeset = assert_invalid?(&Deployment.changeset/2, %{params | name: "secret!!!"})
      assert [name: {^error_message, [validation: :format]}] = changeset.errors

      changeset = assert_invalid?(&Deployment.changeset/2, %{params | name: "secret with spaces"})
      assert [name: {^error_message, [validation: :format]}] = changeset.errors

      changeset = assert_invalid?(&Deployment.changeset/2, %{params | name: "secret 😅"})
      assert [name: {^error_message, [validation: :format]}] = changeset.errors
    end

    test "when description is empty then valid", %{bare_params: params} do
      assert_valid?(&Deployment.changeset/2, %{params | description: ""})
    end

    test "when url is empty then valid", %{bare_params: params} do
      assert_valid?(&Deployment.changeset/2, %{params | url: ""})
    end

    test "when organization_id is empty then invalid", %{bare_params: params} do
      changeset = assert_invalid?(&Deployment.changeset/2, %{params | organization_id: ""})
      assert [organization_id: {"can't be blank", [validation: :required]}] = changeset.errors
    end

    test "when project_id is empty then invalid", %{bare_params: params} do
      changeset = assert_invalid?(&Deployment.changeset/2, %{params | project_id: ""})
      assert [project_id: {"can't be blank", [validation: :required]}] = changeset.errors
    end

    test "when created_by is empty then invalid", %{bare_params: params} do
      changeset = assert_invalid?(&Deployment.changeset/2, %{params | created_by: ""})
      assert [created_by: {"can't be blank", [validation: :required]}] = changeset.errors
    end

    test "when updated_by is empty then invalid", %{bare_params: params} do
      changeset = assert_invalid?(&Deployment.changeset/2, %{params | updated_by: ""})
      assert [updated_by: {"can't be blank", [validation: :required]}] = changeset.errors
    end

    test "when unique_token is empty then invalid", %{bare_params: params} do
      changeset = assert_invalid?(&Deployment.changeset/2, %{params | unique_token: ""})
      assert [unique_token: {"can't be blank", [validation: :required]}] = changeset.errors
    end

    test "when bookmark parameters are not empty then valid", %{bare_params: params} do
      assert_valid?(&Deployment.changeset/2, Map.put(params, :bookmark_parameter1, "test"))
      assert_valid?(&Deployment.changeset/2, Map.put(params, :bookmark_parameter2, "test"))
      assert_valid?(&Deployment.changeset/2, Map.put(params, :bookmark_parameter3, "test"))
    end

    test "casts subject rules", %{bare_params: params, subject_rules: rules} do
      assert_valid?(&Deployment.changeset/2, %{params | subject_rules: rules})
    end

    test "casts object rules", %{bare_params: params, object_rules: rules} do
      assert_valid?(&Deployment.changeset/2, %{params | object_rules: rules})
    end

    test "casts subject rules and overrides existing", ctx do
      old_rules = [
        %Deployment.SubjectRule{type: :USER, subject_id: UUID.uuid4()},
        %Deployment.SubjectRule{type: :ROLE, subject_id: UUID.uuid4()}
      ]

      new_rules = ctx[:subject_rules]

      deployment =
        %Deployment{}
        |> Deployment.changeset(ctx[:bare_params])
        |> Ecto.Changeset.put_embed(:subject_rules, old_rules)
        |> Ecto.Changeset.apply_changes()

      assert %Ecto.Changeset{valid?: true} =
               changeset = Deployment.changeset(deployment, %{subject_rules: new_rules})

      assert changeset |> Ecto.Changeset.apply_changes() |> Map.get(:subject_rules) ==
               Enum.map(new_rules, &struct(Deployment.SubjectRule, &1))
    end

    test "casts object rules and overrides existing", ctx do
      old_rules = [
        %Deployment.ObjectRule{type: :BRANCH, match_mode: :REGEX, pattern: "release/*"},
        %Deployment.ObjectRule{type: :TAG, match_mode: :EXACT, pattern: "\d+\.\d+\.\d+"}
      ]

      new_rules = ctx[:object_rules]

      deployment =
        %Deployment{}
        |> Deployment.changeset(ctx[:bare_params])
        |> Ecto.Changeset.put_embed(:object_rules, old_rules)
        |> Ecto.Changeset.apply_changes()

      assert changeset =
               assert_valid?(deployment, &Deployment.changeset/2, %{object_rules: new_rules})

      assert changeset |> Ecto.Changeset.apply_changes() |> Map.get(:object_rules) ==
               Enum.map(new_rules, &struct(Deployment.ObjectRule, &1))
    end
  end

  describe "set_as_syncing/2" do
    setup [:deployment_from_params]

    test "changes state to :SYNCING", %{deployment: deployment} do
      assert %Deployment{state: :SYNCING} =
               deployment
               |> Deployment.set_as_syncing(UUID.uuid4())
               |> Ecto.Changeset.apply_changes()
    end

    test "updates unique token", %{deployment: deployment} do
      unique_token = UUID.uuid4()

      assert %Deployment{state: :SYNCING, unique_token: ^unique_token} =
               deployment
               |> Deployment.set_as_syncing(unique_token)
               |> Ecto.Changeset.apply_changes()
    end
  end

  describe "set_as_finished/2" do
    setup [:deployment_from_params]

    test "when result = :SUCCESS then changes state and result",
         %{deployment: deployment} do
      assert %Deployment{
               state: :FINISHED,
               result: :SUCCESS
             } =
               deployment
               |> Deployment.set_as_finished(:SUCCESS)
               |> Ecto.Changeset.apply_changes()
    end

    test "when result = :FAILURE then changes state and result",
         %{deployment: deployment} do
      assert %Deployment{
               state: :FINISHED,
               result: :FAILURE
             } =
               deployment
               |> Deployment.set_as_finished(:FAILURE)
               |> Ecto.Changeset.apply_changes()
    end
  end

  describe "put_secret/2" do
    setup [:deployment_from_params]

    test "when both secret_id and secret_name are provided then valid", %{deployment: deployment} do
      assert_valid?(deployment, &Deployment.put_secret/2, %{
        secret_id: UUID.uuid4(),
        secret_name: "Secret name"
      })

      assert_valid?(deployment, &Deployment.put_secret/2, %{
        "secret_id" => UUID.uuid4(),
        "secret_name" => "Secret name"
      })

      assert_valid?(deployment, &Deployment.put_secret/2, %{
        secret_id: UUID.uuid4(),
        secret_name: "Secret name",
        secret_extra: "1234567890"
      })
    end

    test "when secret_id is missing then invalid", %{deployment: deployment} do
      assert_invalid?(deployment, &Deployment.put_secret/2, %{
        secret_name: "Secret name"
      })

      assert_invalid?(deployment, &Deployment.put_secret/2, %{
        "secret_name" => "Secret name"
      })

      assert_invalid?(deployment, &Deployment.put_secret/2, %{
        secret_name: "Secret name",
        secret_extra: "1234567890"
      })
    end

    test "when secret_name is missing then invalid", %{deployment: deployment} do
      assert_invalid?(deployment, &Deployment.put_secret/2, %{
        secret_id: UUID.uuid4()
      })

      assert_invalid?(deployment, &Deployment.put_secret/2, %{
        "secret_id" => UUID.uuid4()
      })

      assert_invalid?(deployment, &Deployment.put_secret/2, %{
        secret_id: UUID.uuid4(),
        secret_extra: "1234567890"
      })
    end
  end

  describe "put_encrypted_secret/2" do
    setup [:deployment_from_params]

    test "when encrypted_secret is nil then valid", %{deployment: deployment} do
      assert_valid?(deployment, &Deployment.put_encrypted_secret/2, nil)
    end

    test "when encrypted_secret is empty map then invalid", %{deployment: deployment} do
      assert_invalid?(deployment, &Deployment.put_encrypted_secret/2, %{})
    end

    test "when encrypted_secret is random map then invalid", %{deployment: deployment} do
      assert_invalid?(deployment, &Deployment.put_encrypted_secret/2, %{foo: "bar"})
    end

    test "when encrypted_secret is valid map then valid", %{deployment: deployment} do
      assert_valid?(deployment, &Deployment.put_encrypted_secret/2, %{
        request_type: "create",
        requester_id: UUID.uuid4(),
        unique_token: UUID.uuid4(),
        key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
        aes256_key: random_payload(256),
        init_vector: random_payload(256),
        payload: random_payload()
      })
    end

    test "when encrypted_secret is valid struct then valid", %{deployment: deployment} do
      secret = %Deployment.EncryptedSecret{
        request_type: :create,
        requester_id: UUID.uuid4(),
        unique_token: UUID.uuid4(),
        key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
        aes256_key: random_payload(256),
        init_vector: random_payload(256),
        payload: random_payload()
      }

      assert_valid?(deployment, &Deployment.put_encrypted_secret/2, secret)
    end
  end

  defp assert_valid?(deployment \\ %Deployment{}, changeset_fun, params) do
    changeset = changeset_fun.(deployment, params)
    assert changeset.valid?
    changeset
  end

  defp assert_invalid?(deployment \\ %Deployment{}, changeset_fun, params) do
    changeset = changeset_fun.(deployment, params)
    refute changeset.valid?
    changeset
  end

  defp deployment_from_params(%{bare_params: params}) do
    {:ok,
     deployment:
       %Deployment{}
       |> Deployment.changeset(params)
       |> Ecto.Changeset.apply_changes()}
  end

  defp random_payload(n_bytes \\ 4_096) do
    round(n_bytes) |> :crypto.strong_rand_bytes() |> Base.encode64()
  end
end
