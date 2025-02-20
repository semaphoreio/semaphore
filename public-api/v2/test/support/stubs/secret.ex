defmodule Support.Stubs.Secret do
  #
  # TODO: This stub is not complete. Some values are still hardcoded. DO NOT COPY.
  #
  # Hardcoding id values and API responses does not scale well. The more tests
  # we add that really on hardcoding, the harder it will become to untangle
  # the tests in the future.
  #

  alias Support.Stubs.{DB, UUID}

  def init do
    DB.add_table(:deployment_secrets, [:id, :name, :dt_id, :api_model])
    DB.add_table(:secrets, [:id, :name, :api_model, :level])

    __MODULE__.Keys.init()
    __MODULE__.Grpc.init()
  end

  def all, do: DB.all(:secrets)
  def last, do: all() |> hd()
  def first, do: all() |> hd()

  def find_list(:ORGANIZATION) do
    DB.filter(:secrets, fn s -> s.level == :ORGANIZATION end)
  end

  def find_list(:PROJECT, project_id) do
    DB.filter(:secrets, fn s ->
      s.level == :PROJECT && s.api_model.project_config.project_id == project_id
    end)
  end

  def create_default(_meta \\ [], _envs \\ [], _files \\ []) do
    create()
  end

  def create(
        name \\ "bag-of-secrets",
        params \\ %{level: :ORGANIZATION, project_id: ""},
        meta \\ [],
        _envs \\ [],
        _files \\ []
      ) do
    # alias Semaphore.Secrets.V1beta.Secret
    alias InternalApi.Secrethub.Secret

    meta =
      Map.merge(
        %Secret.Metadata{
          name: name,
          id: UUID.gen(),
          org_id: Map.get(params, :org_id, UUID.gen()),
          created_at: %Google.Protobuf.Timestamp{seconds: Timex.to_unix(Timex.now())},
          updated_at: %Google.Protobuf.Timestamp{seconds: Timex.to_unix(Timex.now())},
          created_by: Support.Stubs.User.default_user_id(),
          updated_by: Support.Stubs.User.default_user_id(),
          level: params.level
        },
        Map.new(meta)
      )

    data = %Secret.Data{
      env_vars: [%Secret.EnvVar{name: "secret-1", value: "hello"}],
      files: []
    }

    api_model = %Secret{
      metadata: meta,
      data: data,
      org_config: %Secret.OrgConfig{},
      project_config: %Secret.ProjectConfig{project_id: params.project_id}
    }

    DB.insert(:secrets, %{
      id: meta.id,
      name: meta.name,
      level: params.level,
      api_model: api_model
    })
  end

  defmodule Keys do
    use Agent

    def init, do: Agent.start_link(&generate_key_pair/0, name: __MODULE__)
    def get_key, do: Agent.get(__MODULE__, & &1)

    def encrypt(secret_data) do
      do_encrypt(secret_data, get_key())
    end

    def decrypt(encrypted) do
      do_decrypt(encrypted, get_key())
    end

    defp do_encrypt(secret_data, %{key_id: key_id, public_key: public_key}) do
      encoded_payload = InternalApi.Secrethub.Secret.Data.encode(secret_data)

      with {:ok, aes256_key} <- ExCrypto.generate_aes_key(:aes_256, :bytes),
           {:ok, {init_vector, encrypted_payload}} <-
             ExCrypto.encrypt(aes256_key, encoded_payload),
           {:ok, encrypted_aes256_key} <- ExPublicKey.encrypt_public(aes256_key, public_key),
           {:ok, encrypted_init_vector} <- ExPublicKey.encrypt_public(init_vector, public_key) do
        {:ok,
         %{
           key_id: to_string(key_id),
           aes256_key: to_string(encrypted_aes256_key),
           init_vector: to_string(encrypted_init_vector),
           payload: Base.encode64(encrypted_payload)
         }}
      end
    end

    defp do_decrypt(encrypted, %{private_key: private_key}) do
      with {:ok, init_vector} <- ExPublicKey.decrypt_private(encrypted.init_vector, private_key),
           {:ok, aes256_key} <- ExPublicKey.decrypt_private(encrypted.aes256_key, private_key),
           {:ok, payload} <- Base.decode64(encrypted.payload),
           {:ok, payload} <- ExCrypto.decrypt(aes256_key, init_vector, payload) do
        {:ok, InternalApi.Secrethub.Secret.Data.decode(payload)}
      end
    end

    defp generate_key_pair do
      {:ok, private_key} = ExPublicKey.generate_key()
      {:ok, public_key} = ExPublicKey.public_key_from_private_key(private_key)
      key_id = DateTime.utc_now() |> DateTime.to_unix() |> to_string()

      %{key_id: key_id, public_key: public_key, private_key: private_key}
    end
  end

  defmodule Grpc do
    alias InternalApi.Secrethub.ResponseMeta

    def init do
      GrpcMock.stub(SecretMock, :create, &__MODULE__.create/2)
      GrpcMock.stub(SecretMock, :list, &__MODULE__.list/2)
      GrpcMock.stub(SecretMock, :list_keyset, &__MODULE__.list_keyset/2)
      GrpcMock.stub(SecretMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(SecretMock, :update, &__MODULE__.update/2)
      GrpcMock.stub(SecretMock, :destroy, &__MODULE__.destroy/2)
      GrpcMock.stub(SecretMock, :get_key, &__MODULE__.get_key/2)
    end

    def describe(req, _) do
      case find(req) do
        {:ok, secret} ->
          %InternalApi.Secrethub.DescribeResponse{
            secret: secret,
            metadata: %ResponseMeta{
              status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
            }
          }

        {:error, :missing_arg} ->
          %InternalApi.Secrethub.DescribeResponse{
            metadata: %ResponseMeta{
              status: %ResponseMeta.Status{
                code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
                message: "Missing lookup argument"
              }
            }
          }

        {:error, message} ->
          %InternalApi.Secrethub.DescribeResponse{
            metadata: %ResponseMeta{
              status: %ResponseMeta.Status{
                code: ResponseMeta.Code.value(:NOT_FOUND),
                message: message
              }
            }
          }

          # raise GRPC.RPCError, status: 5, message: message
      end
    end

    def destroy(req, _) do
      case find(req) do
        {:ok, secret} ->
          %InternalApi.Secrethub.DestroyResponse{
            metadata: %InternalApi.Secrethub.ResponseMeta{
              status: %InternalApi.Secrethub.ResponseMeta.Status{
                code: :OK,
                message: "Secret destroyed"
              }
            },
            id: secret.metadata.id
          }

        {:error, _message} ->
          %InternalApi.Secrethub.DestroyResponse{
            metadata: %InternalApi.Secrethub.ResponseMeta{
              status: %InternalApi.Secrethub.ResponseMeta.Status{
                code: :NOT_FOUND,
                message: "Secret not found"
              }
              # todo: this is tmp solution while destroyresponse does not have id field
            }
          }
      end
    end

    def create(req, _) do
      alias InternalApi.Secrethub.Secret
      alias InternalApi.Secrethub.ResponseMeta

      id = UUID.gen()
      name = req.secret.metadata.name

      secret = new_secret(req.secret, req.metadata.org_id, req.metadata.user_id, id)
      level = req.secret.metadata.level || :ORGANIZATION

      exists? = find(name) != nil

      if exists? do
        %InternalApi.Secrethub.CreateResponse{
          metadata: %ResponseMeta{
            status: %ResponseMeta.Status{
              code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
              message: "name has already been taken"
            }
          },
          secret: secret
        }
      else
        DB.insert(:secrets, %{id: id, name: name, api_model: secret, level: level})

        %InternalApi.Secrethub.CreateResponse{
          secret: secret,
          metadata: %ResponseMeta{
            user_id: req.metadata.user_id,
            status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
          }
        }
      end
    end

    def update(req, _) do
      alias InternalApi.Secrethub.Secret
      alias InternalApi.Secrethub.UpdateResponse

      case find(req) do
        {:ok, _secret} ->
          new_secret = %{
            id: req.secret.metadata.id,
            name: req.secret.metadata.name,
            api_model:
              new_secret(
                req.secret,
                req.metadata.org_id,
                req.metadata.user_id,
                req.secret.metadata.id
              ),
            level: req.secret.metadata.level || :PROJECT
          }

          DB.update(:secrets, new_secret)

          require Logger
          Logger.debug("secret updated: #{inspect(new_secret)}")

          %UpdateResponse{
            secret: new_secret.api_model,
            metadata: %ResponseMeta{
              status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}
            }
          }

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message <> "#{inspect(req)}"
      end
    end

    def list(_req, _) do
      alias InternalApi.Secrethub.ListResponse

      secrets = DB.all(:secrets) |> DB.extract(:api_model)

      %ListResponse{secrets: secrets}
    end

    def list_keyset(req, _) do
      alias InternalApi.Secrethub.ListKeysetResponse

      filter_id =
        if req.secret_level == :ORGANIZATION, do: req.metadata.org_id, else: req.project_id

      all_secrets =
        find_list(req.secret_level, filter_id)
        |> Enum.drop_while(fn s -> req.page_token not in ["", s.metadata.id] end)

      resp_secrets = all_secrets |> Enum.take(req.page_size)

      page_token =
        if length(resp_secrets) < length(all_secrets) do
          Enum.at(all_secrets, req.page_size) |> Map.get(:metadata) |> Map.get(:id)
        else
          ""
        end

      %ListKeysetResponse{
        metadata: %ResponseMeta{status: %ResponseMeta.Status{code: ResponseMeta.Code.value(:OK)}},
        secrets: resp_secrets,
        next_page_token: page_token
      }
    end

    def get_key(_req, _) do
      %{key_id: key_id, public_key: public_key} = Support.Stubs.Secret.Keys.get_key()
      {:ok, der_public_key} = ExPublicKey.RSAPublicKey.encode_der(public_key)
      %InternalApi.Secrethub.GetKeyResponse{id: key_id, key: Base.encode64(der_public_key)}
    end

    defp find(_req = %{secret_level: :PROJECT, id: "", name: ""}) do
      {:error, :missing_arg}
    end

    defp find(_req = %{secret_level: :PROJECT, id: "", name: name}) do
      case DB.filter(:secrets, fn s -> s.level == :PROJECT && s.name == name end) do
        [] ->
          {:error, "Secret not found"}

        secrets ->
          secret = hd(secrets)
          {:ok, secret.api_model}
      end
    end

    defp find(_req = %{secret_level: :PROJECT, id: id}) when id != "" do
      case DB.find(:secrets, id) do
        nil -> {:error, "Secret not found"}
        secret -> {:ok, secret.api_model}
      end
    end

    defp find(_req = %{secret_level: :DEPLOYMENT_TARGET, id: id}) when id != "" do
      case DB.find(:deployment_secrets, id) do
        nil -> {:error, "DT Secret not found"}
        secret -> {:ok, secret.api_model}
      end
    end

    defp find(_req = %{secret_level: :DEPLOYMENT_TARGET, deployment_target_id: dt_id})
         when dt_id != "" do
      case DB.find_by(:deployment_secrets, :dt_id, dt_id) do
        nil -> {:error, "DT Secret not found by dt_id"}
        secret -> {:ok, secret.api_model}
      end
    end

    defp find(req = %{secret_id_or_name: _}) when is_struct(req) do
      case Enum.find(DB.all(:secrets), fn s ->
             (s.id == req.secret_id_or_name || s.name == req.secret_id_or_name) &&
               s.api_model.metadata.org_id == req.metadata.org_id
           end) do
        nil ->
          {:error, "Secret #{req.secret_id_or_name} not found"}

        secret ->
          {:ok, secret}
      end
    end

    defp find(%{id: id, name: ""}) do
      case DB.find(:secrets, id) do
        nil ->
          {:error, "Secret not found"}

        secret ->
          {:ok, secret.api_model}
      end
    end

    defp find(req = %{id: "", name: name}) do
      Enum.find(DB.all(:secrets), fn s ->
        s.name == req.name && s.api_model.metadata.org_id == req.metadata.org_id
      end)
      |> case do
        nil ->
          {:error, "Secret #{name} not found"}

        secret ->
          {:ok, secret.api_model}
      end
    end

    defp find(%{secret: secret}) do
      case DB.find_by(:secrets, :id, secret.metadata.id) do
        nil ->
          {:error, "secret #{secret.metadata.name} not found"}

        secret ->
          {:ok, secret}
      end
    end

    defp find(name) do
      DB.find_by(:secrets, :name, name)
    end

    defp find_list(:ORGANIZATION, org_id) do
      DB.filter(:secrets, fn s ->
        s.level == :ORGANIZATION && s.api_model.metadata.org_id == org_id
      end)
      |> DB.extract(:api_model)
    end

    defp find_list(:PROJECT, project_id) do
      DB.filter(:secrets, fn s ->
        s.level == :PROJECT && s.api_model.project_config.project_id == project_id
      end)
      |> DB.extract(:api_model)
    end

    defp new_secret(secret, org_id, user_id, id) do
      alias InternalApi.Secrethub.Secret
      name = secret.metadata.name

      %Secret{
        data: secret.data,
        metadata: %Secret.Metadata{
          name: name,
          description: secret.metadata.description,
          id: id,
          org_id: org_id,
          created_by: user_id,
          updated_by: user_id,
          created_at: %Google.Protobuf.Timestamp{seconds: Timex.to_unix(Timex.now())},
          updated_at: %Google.Protobuf.Timestamp{seconds: Timex.to_unix(Timex.now())},
          level: secret.metadata.level
        },
        org_config: secret.org_config || %Secret.OrgConfig{},
        project_config: secret.project_config || %Secret.ProjectConfig{}
      }
    end
  end
end
