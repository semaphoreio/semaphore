defmodule Gofer.Deployment.Model.Deployment.EncryptedSecretTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias Gofer.Deployment.Model.Deployment.EncryptedSecret
  @secret_fields ~w(key_id aes256_key init_vector payload)a

  setup do
    {:ok,
     params: %{
       request_type: nil,
       error_message: nil,
       requester_id: UUID.uuid4(),
       unique_token: UUID.uuid4(),
       key_id: DateTime.utc_now() |> DateTime.to_unix() |> to_string(),
       aes256_key: random_payload(256),
       init_vector: random_payload(256),
       payload: random_payload()
     }}
  end

  describe "changeset/2" do
    test "with all parameters is valid", ctx do
      assert_valid?(%{ctx.params | request_type: :create, error_message: ":timeout"})
      assert_valid?(%{ctx.params | request_type: :update, error_message: ":timeout"})
      assert_valid?(%{ctx.params | request_type: :delete, error_message: ":timeout"})
    end

    test "without error_message is valid", ctx do
      assert_valid?(%{ctx.params | request_type: :create, error_message: ""})
      assert_valid?(%{ctx.params | request_type: :update, error_message: ""})
      assert_valid?(%{ctx.params | request_type: :delete, error_message: ""})
    end

    test "without request_type is invalid", ctx do
      assert_invalid?(%{ctx.params | request_type: nil})
    end

    test "without requester_id is invalid", ctx do
      assert_invalid?(%{ctx.params | request_type: :create, requester_id: ""})
      assert_invalid?(%{ctx.params | request_type: :update, requester_id: ""})
      assert_invalid?(%{ctx.params | request_type: :delete, requester_id: ""})
    end

    test "without unique_token is invalid", ctx do
      assert_invalid?(%{ctx.params | request_type: :create, unique_token: ""})
      assert_invalid?(%{ctx.params | request_type: :update, unique_token: ""})
      assert_invalid?(%{ctx.params | request_type: :delete, unique_token: ""})
    end

    test "request_payload is mandatory but for DELETE requests", ctx do
      for field <- @secret_fields do
        %{ctx.params | request_type: :create}
        |> Map.drop([field])
        |> assert_invalid?()

        %{ctx.params | request_type: :update}
        |> Map.drop([field])
        |> assert_invalid?()

        %{ctx.params | request_type: :delete}
        |> Map.drop([field])
        |> assert_valid?()
      end
    end
  end

  describe "new/2" do
    test "when request_type = :create and payload is provided then returns new secret", ctx do
      assert %Ecto.Changeset{valid?: true} = EncryptedSecret.new(:create, ctx.params)
    end

    test "when request_type = :create and payload isn't provided then returns error", ctx do
      params = Map.drop(ctx.params, ~w(key_id aes256_key init_vector payload)a)

      assert %Ecto.Changeset{
               valid?: false,
               errors: [
                 key_id: {"can't be blank", _},
                 aes256_key: {"can't be blank", _},
                 init_vector: {"can't be blank", _},
                 payload: {"can't be blank", _}
               ]
             } = EncryptedSecret.new(:create, params)
    end

    test "when request_type = :create and requester ID is not provided then returns error", ctx do
      params = Map.drop(ctx.params, [:requester_id])

      assert %Ecto.Changeset{
               valid?: false,
               errors: [requester_id: {"can't be blank", _}]
             } = EncryptedSecret.new(:create, params)
    end

    test "when request_type = :create and unique token is not provided then returns error", ctx do
      params = Map.drop(ctx.params, [:unique_token])

      assert %Ecto.Changeset{
               valid?: false,
               errors: [unique_token: {"can't be blank", _}]
             } = EncryptedSecret.new(:create, params)
    end

    test "when request_type = :update and payload is provided then returns new secret", ctx do
      assert %Ecto.Changeset{valid?: true} = EncryptedSecret.new(:update, ctx.params)
    end

    test "when request_type = :update and payload is not provided then returns error changeset",
         ctx do
      params = Map.drop(ctx.params, ~w(key_id aes256_key init_vector payload)a)

      assert %Ecto.Changeset{
               valid?: false,
               errors: [
                 key_id: {"can't be blank", _},
                 aes256_key: {"can't be blank", _},
                 init_vector: {"can't be blank", _},
                 payload: {"can't be blank", _}
               ]
             } = EncryptedSecret.new(:update, params)
    end

    test "when request_type = :update and requester ID is not provided then returns error changeset",
         ctx do
      params = Map.drop(ctx.params, [:requester_id])

      assert %Ecto.Changeset{
               valid?: false,
               errors: [requester_id: {"can't be blank", _}]
             } = EncryptedSecret.new(:update, params)
    end

    test "when request_type = :update and unique token is not provided then returns error changeset",
         ctx do
      params = Map.drop(ctx.params, [:unique_token])

      assert %Ecto.Changeset{
               valid?: false,
               errors: [unique_token: {"can't be blank", _}]
             } = EncryptedSecret.new(:update, params)
    end

    test "when request_type = :delete and payload is provided then returns new secret", ctx do
      assert %Ecto.Changeset{valid?: true} = EncryptedSecret.new(:delete, ctx.params)
    end

    test "when request_type = :delete and payload is not provided then returns new secret",
         ctx do
      params = Map.drop(ctx.params, ~w(key_id aes256_key init_vector payload)a)

      assert %Ecto.Changeset{valid?: true} = EncryptedSecret.new(:delete, params)
    end

    test "when request_type = :delete and requester ID is not provided then returns error", ctx do
      assert %Ecto.Changeset{
               valid?: false,
               errors: [requester_id: {"can't be blank", _}]
             } = EncryptedSecret.new(:delete, Map.delete(ctx.params, :requester_id))
    end
  end

  describe "with_error/2" do
    test "when reason is string then stores it literally", ctx do
      prev_secret = struct(EncryptedSecret, ctx.params)
      secret = EncryptedSecret.with_error(prev_secret, "timeout")

      for field <- ~w(request_type requester_id key_id aes256_key init_vector payload)a do
        assert Ecto.Changeset.get_field(secret, field) == Map.get(prev_secret, field)
      end

      assert Ecto.Changeset.get_field(secret, :error_message) == "timeout"
    end

    test "when reason is other term then stores it as string", ctx do
      prev_secret = struct(EncryptedSecret, ctx.params)
      secret = EncryptedSecret.with_error(prev_secret, :timeout)

      for field <- ~w(request_type requester_id key_id aes256_key init_vector payload)a do
        assert Ecto.Changeset.get_field(secret, field) == Map.get(prev_secret, field)
      end

      assert Ecto.Changeset.get_field(secret, :error_message) == ":timeout"
    end
  end

  defp assert_valid?(params) do
    changeset = EncryptedSecret.changeset(%EncryptedSecret{}, params)
    assert changeset.valid?
    changeset
  end

  defp assert_invalid?(params) do
    changeset = EncryptedSecret.changeset(%EncryptedSecret{}, params)
    refute changeset.valid?
    changeset
  end

  defp random_payload(n_bytes \\ 4_096) do
    round(n_bytes) |> :crypto.strong_rand_bytes() |> Base.encode64()
  end
end
