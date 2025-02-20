defmodule Support.Stubs.Secret do
  alias Support.Stubs.{DB, UUID}
  alias Util.Proto

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
    DB.filter(:secrets, fn s -> s.level == 0 end)
  end

  def find_list(:PROJECT, project_id) do
    DB.filter(:secrets, fn s ->
      s.level == 1 && s.api_model.project_config.project_id == project_id
    end)
  end

  def create_default(_meta \\ [], _envs \\ [], _files \\ []) do
    create()
  end

  def create(
        name \\ "bag-of-secrets",
        params \\ %{level: :ORGANIZATION, project_id: ""},
        _meta \\ [],
        _envs \\ [],
        _files \\ []
      ) do
    # alias Semaphore.Secrets.V1beta.Secret
    alias InternalApi.Secrethub.Secret

    meta =
      Secret.Metadata.new(
        name: name,
        id: UUID.gen(),
        created_at: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(Timex.now())),
        updated_at: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(Timex.now())),
        created_by: Support.Stubs.User.default_user_id(),
        updated_by: Support.Stubs.User.default_user_id(),
        secret_level: params.level
      )

    data =
      Secret.Data.new(
        env_vars: [Secret.EnvVar.new(name: "secret-1", value: "hello")],
        files: []
      )

    api_model =
      Secret.new(
        metadata: meta,
        data: data,
        org_config: Secret.OrgConfig.new(),
        secret_level: Secret.SecretLevel.value(params.level),
        project_config: Secret.ProjectConfig.new(project_id: params.project_id)
      )

    DB.insert(:secrets, %{
      id: meta.id,
      name: meta.name,
      level: Secret.SecretLevel.value(params.level),
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
          InternalApi.Secrethub.DescribeResponse.new(
            secret: secret,
            metadata:
              ResponseMeta.new(
                status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))
              )
          )

        {:error, :missing_arg} ->
          InternalApi.Secrethub.DescribeResponse.new(
            metadata:
              ResponseMeta.new(
                status:
                  ResponseMeta.Status.new(
                    code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
                    message: "Missing lookup argument"
                  )
              )
          )

        {:error, message} ->
          InternalApi.Secrethub.DescribeResponse.new(
            metadata:
              ResponseMeta.new(
                status:
                  ResponseMeta.Status.new(
                    code: ResponseMeta.Code.value(:NOT_FOUND),
                    message: message
                  )
              )
          )
      end
    end

    def destroy(req, _) do
      case find(req) do
        {:ok, _} ->
          %{
            metadata: %{
              status: %{code: :OK, message: "Secret destroyed"}
            }
          }
          |> Proto.deep_new!(InternalApi.Secrethub.DestroyResponse)

        {:error, message} ->
          raise GRPC.RPCError, status: 5, message: message
      end
    end

    def create(req, _) do
      alias InternalApi.Secrethub.ResponseMeta
      alias InternalApi.Secrethub.Secret

      id = Ecto.UUID.generate()
      name = req.secret.metadata.name

      secret = new_secret(req.secret, req.metadata.org_id, req.metadata.user_id, id)
      level = req.secret.metadata.level || 0

      exists? = find(name) != nil

      if exists? do
        InternalApi.Secrethub.CreateResponse.new(
          metadata:
            ResponseMeta.new(
              status:
                ResponseMeta.Status.new(
                  code: ResponseMeta.Code.value(:FAILED_PRECONDITION),
                  message: "name has already been taken"
                )
            ),
          secret: secret
        )
      else
        DB.insert(:secrets, %{id: id, name: name, api_model: secret, level: level})

        InternalApi.Secrethub.CreateResponse.new(
          secret: secret,
          metadata:
            ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK)))
        )
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
            level: req.secret.metadata.level || 0
          }

          DB.update(:secrets, new_secret)

          require Logger
          Logger.info("secret updated: #{inspect(new_secret)}")

          UpdateResponse.new(
            secret: new_secret.api_model,
            metadata:
              ResponseMeta.new(
                status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))
              )
          )

        {:error, message} ->
          raise GRPC.RPCError, status: :not_found, message: message <> "#{inspect(req)}"
      end
    end

    def list(_req, _) do
      alias InternalApi.Secrethub.ListResponse

      secrets = DB.all(:secrets) |> DB.extract(:api_model)

      ListResponse.new(secrets: secrets)
    end

    def list_keyset(req, _) do
      alias InternalApi.Secrethub.ListKeysetResponse

      secrets = find_list(req.secret_level, req.project_id)

      ListKeysetResponse.new(
        metadata:
          ResponseMeta.new(status: ResponseMeta.Status.new(code: ResponseMeta.Code.value(:OK))),
        secrets: secrets
      )
    end

    def get_key(_req, _) do
      %{key_id: key_id, public_key: public_key} = Support.Stubs.Secret.Keys.get_key()
      {:ok, der_public_key} = ExPublicKey.RSAPublicKey.encode_der(public_key)
      InternalApi.Secrethub.GetKeyResponse.new(id: key_id, key: Base.encode64(der_public_key))
    end

    defp find(_req = %{secret_level: 2, id: "", deployment_target_id: ""}) do
      {:error, :missing_arg}
    end

    defp find(_req = %{secret_level: 2, id: id}) when id != "" do
      case DB.find(:deployment_secrets, id) do
        nil -> {:error, "Secret not found"}
        secret -> {:ok, secret.api_model}
      end
    end

    defp find(_req = %{secret_level: 2, deployment_target_id: dt_id})
         when dt_id != "" do
      case DB.find_by(:deployment_secrets, :dt_id, dt_id) do
        nil -> {:error, "Secret not found"}
        secret -> {:ok, secret.api_model}
      end
    end

    defp find(_req = %{secret_level: 1, id: ""}) do
      {:error, :missing_arg}
    end

    defp find(_req = %{secret_level: 1, id: id}) when id != "" do
      case DB.find(:secrets, id) do
        nil -> {:error, "Secret not found"}
        secret -> {:ok, secret.api_model}
      end
    end

    defp find(req = %{secret_id_or_name: _}) when is_struct(req) do
      case Enum.find(DB.all(:secrets), fn s ->
             s.id == req.secret_id_or_name || s.name == req.secret_id_or_name
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

    defp find(%{id: "", name: name}) do
      case DB.find_by(:secrets, :name, name) do
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

    defp find_list(0, _project_id) do
      DB.filter(:secrets, fn s -> s.level == 0 end) |> DB.extract(:api_model)
    end

    defp find_list(1, project_id) do
      DB.filter(:secrets, fn s ->
        s.level == 1 && s.api_model.project_config.project_id == project_id
      end)
      |> DB.extract(:api_model)
    end

    defp new_secret(secret, org_id, user_id, id) do
      alias InternalApi.Secrethub.Secret
      name = secret.metadata.name

      Secret.new(
        data: secret.data,
        metadata:
          Secret.Metadata.new(
            name: name,
            description: secret.metadata.description,
            id: id,
            org_id: org_id,
            created_by: user_id,
            updated_by: user_id,
            created_at: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(Timex.now())),
            updated_at: Google.Protobuf.Timestamp.new(seconds: Timex.to_unix(Timex.now())),
            level: secret.metadata.level
          ),
        org_config: secret.org_config || Secret.OrgConfig.new(%{}),
        project_config: secret.project_config || Secret.ProjectConfig.new(%{})
      )
    end
  end
end
