defmodule Support.Stubs.Deployments do
  alias Support.Stubs.{DB, UUID}
  alias Support.Stubs.Time, as: StubTime

  def init do
    DB.add_table(:deployment_targets, ~w(id project_id name unique_token api_model history)a)

    __MODULE__.Grpc.init()
  end

  def create(project, user, name, params \\ []) do
    target_id = UUID.gen()
    now = Map.from_struct(StubTime.now())
    params = Map.new(params)

    params =
      Map.merge(params, %{
        id: target_id,
        name: name,
        organization_id: project.org_id,
        project_id: project.id,
        created_by: user.id,
        updated_by: user.id,
        created_at: now,
        updated_at: now,
        cordoned: params[:cordoned] || false,
        state: params[:state] || :USABLE,
        state_message: "",
        env_vars: Map.get(params, :env_vars, []),
        files: Map.get(params, :files, []),
        unique_token: Map.get(params, :unique_token, UUID.gen()),
        secret_id: UUID.gen(),
        secret_name: "dt.#{target_id}"
      })

    target = insert_deployment_target(params)
    secret = insert_deployment_secret(params)
    {target, secret}
  end

  defp insert_deployment_target(params) do
    alias InternalApi.Gofer.DeploymentTargets.DeploymentTarget

    DB.insert(:deployment_targets, %{
      id: params[:id],
      project_id: params[:project_id],
      name: params[:name],
      unique_token: params[:unique_token],
      api_model: Util.Proto.deep_new!(DeploymentTarget, params),
      history: []
    })
  end

  defp insert_deployment_secret(params) do
    DB.insert(:deployment_secrets, %{
      id: params[:secret_id],
      name: params[:secret_name],
      dt_id: params[:id],
      api_model:
        Util.Proto.deep_new!(
          InternalApi.Secrethub.Secret,
          %{
            metadata: %{
              id: params[:secret_id],
              name: params[:secret_name],
              org_id: params[:organization_id],
              level: :DEPLOYMENT_TARGET,
              created_by: params[:created_by],
              updated_by: params[:updated_by],
              created_at: params[:created_at],
              updated_at: params[:updated_at]
            },
            data: %{
              env_vars: params[:env_vars],
              files: params[:files]
            },
            dt_config: %{
              deployment_target_id: params[:id]
            }
          }
        )
    })
  end

  def put_last_deployment(target, user, switch, params) do
    alias InternalApi.Gofer.DeploymentTargets.DeploymentTarget
    now = Map.from_struct(StubTime.now())

    deployment = %{
      id: UUID.gen(),
      target_id: target.id,
      prev_pipeline_id: switch.pipeline_id,
      pipeline_id: params[:pipeline_id] || "",
      triggered_by: user.id,
      triggered_at: params[:triggered_at] || now,
      switch_id: switch.id,
      target_name: "Deploy to #{target.name}",
      state: params[:state] || :PENDING,
      state_message: params[:state_message] || ""
    }

    api_model =
      target.api_model
      |> Util.Proto.to_map!()
      |> Map.put(:last_deployment, deployment)
      |> Util.Proto.deep_new!(DeploymentTarget)

    DB.upsert(:deployment_targets, %{target | api_model: api_model})
  end

  def add_deployment(target, user, switch, params) do
    alias InternalApi.Gofer.DeploymentTargets.Deployment
    now = Map.from_struct(StubTime.now())

    deployment =
      Util.Proto.deep_new!(Deployment, %{
        id: UUID.gen(),
        target_id: target.id,
        prev_pipeline_id: switch.pipeline_id,
        pipeline_id: params[:pipeline_id] || "",
        switch_id: switch.id,
        target_name: "Deploy to #{target.name}",
        triggered_by: user.id,
        triggered_at: params[:triggered_at] || now,
        state: params[:state] || :PENDING,
        state_message: params[:state_message] || ""
      })

    DB.upsert(:deployment_targets, %{target | history: [deployment | target.history]})
  end

  defmodule Grpc do
    alias InternalApi.Gofer.DeploymentTargets, as: API
    alias Support.Stubs.Secret.Keys, as: SecretKeys
    @mock_name DeploymentsMock

    def init do
      GrpcMock.stub(@mock_name, :list, &__MODULE__.list/2)
      GrpcMock.stub(@mock_name, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(@mock_name, :history, &__MODULE__.history/2)
      GrpcMock.stub(@mock_name, :cordon, &__MODULE__.cordon/2)
      GrpcMock.stub(@mock_name, :create, &__MODULE__.create/2)
      GrpcMock.stub(@mock_name, :update, &__MODULE__.update/2)
      GrpcMock.stub(@mock_name, :delete, &__MODULE__.delete/2)
    end

    def expect(function, n \\ 1, callback) do
      GrpcMock.expect(@mock_name, function, n, fn _request, _stream ->
        callback.()
      end)

      ExUnit.Callbacks.on_exit(fn ->
        __MODULE__.init()
      end)
    end

    def list(request = %API.ListRequest{}, _stream),
      do: request |> Util.Proto.to_map!(transformations: transformations()) |> list()

    def describe(request = %API.DescribeRequest{}, _stream),
      do: request |> Util.Proto.to_map!(transformations: transformations()) |> describe()

    def history(request = %API.HistoryRequest{}, _stream),
      do: request |> Util.Proto.to_map!(transformations: transformations()) |> history()

    def cordon(request = %API.CordonRequest{}, _stream),
      do: request |> Util.Proto.to_map!(transformations: transformations()) |> cordon()

    def create(request = %API.CreateRequest{}, _stream) do
      request |> Util.Proto.to_map!(transformations: transformations()) |> create()
    end

    def update(request = %API.UpdateRequest{}, _stream),
      do: request |> Util.Proto.to_map!(transformations: transformations()) |> update()

    def delete(request = %API.DeleteRequest{}, _stream),
      do: request |> Util.Proto.to_map!(transformations: transformations()) |> delete()

    defp list(%{project_id: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: project_id"
    end

    defp list(%{project_id: project_id}) do
      targets =
        :deployment_targets
        |> DB.find_all_by(:project_id, project_id)
        |> Enum.map(& &1.api_model)

      API.ListResponse.new(targets: targets)
    end

    defp describe(%{target_id: "", project_id: "", target_name: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing arguments: target_id or (project_id, target_name)"
    end

    defp describe(%{target_id: target_id, project_id: "", target_name: ""}) do
      case DB.find(:deployment_targets, target_id) do
        nil -> raise GRPC.RPCError, status: :not_found, message: "Target not found"
        target -> API.DescribeResponse.new(target: target.api_model)
      end
    end

    defp describe(%{target_id: target_id, project_id: project_id, target_name: ""}) do
      case DB.filter(:deployment_targets, project_id: project_id, id: target_id) do
        [] -> raise GRPC.RPCError, status: :not_found, message: "Target not found"
        [target] -> API.DescribeResponse.new(target: target.api_model)
      end
    end

    defp describe(%{target_id: "", project_id: project_id, target_name: target_name}) do
      case DB.filter(:deployment_targets, project_id: project_id, name: target_name) do
        [] -> raise GRPC.RPCError, status: :not_found, message: "Target not found"
        [target] -> API.DescribeResponse.new(target: target.api_model)
      end
    end

    defp history(%{target_id: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: target_id"
    end

    defp history(%{target_id: target_id}) do
      case DB.find(:deployment_targets, target_id) do
        nil -> raise GRPC.RPCError, status: :not_found, message: "Target not found"
        target -> API.HistoryResponse.new(deployments: target.history)
      end
    end

    defp cordon(%{target_id: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: target_id"
    end

    defp cordon(%{target_id: target_id, cordoned: cordoned}) do
      case DB.find(:deployment_targets, target_id) do
        nil ->
          raise GRPC.RPCError, status: :not_found, message: "Target not found"

        target ->
          state = if cordoned, do: 3, else: 1
          api_model = %{target.api_model | state: state, cordoned: cordoned}
          target = %{target | api_model: api_model}
          Support.Stubs.DB.upsert(:deployment_targets, target)
          API.CordonResponse.new(target_id: target_id, cordoned: cordoned)
      end
    end

    defp create(%{unique_token: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: unique_token"
    end

    defp create(%{requester_id: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: requester_id"
    end

    defp create(request = %{target: target_params, secret: secret_params}) do
      target = API.DeploymentTarget.new()

      if not valid?(target, target_params, secret_params) do
        raise GRPC.RPCError, status: :invalid_argument, message: "Changeset error"
      end

      secret_id = UUID.gen()
      target_id = UUID.gen()
      target = upsert_target(request, target_id, secret_id)
      API.CreateResponse.new(target: target.api_model)
    end

    defp update(%{unique_token: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: unique_token"
    end

    defp update(%{requester_id: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: requester_id"
    end

    defp update(request = %{target: target_params, secret: secret_params}) do
      target = DB.find(:deployment_targets, target_params.id)

      unless target do
        raise GRPC.RPCError, status: :not_found, message: "Target not found"
      end

      secret = DB.find_by(:deployment_secrets, :dt_id, target.id)

      if not valid?(target, target_params, secret_params) do
        raise GRPC.RPCError, status: :invalid_argument, message: "Changeset error"
      end

      target_params = target.api_model |> Util.Proto.to_map!() |> Map.merge(target_params)
      request = %{request | target: target_params}
      target = upsert_target(request, target.id, secret && secret.id, target.history)
      API.UpdateResponse.new(target: target.api_model)
    end

    defp delete(%{target_id: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: target_id"
    end

    defp delete(%{requester_id: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: requester_id"
    end

    defp delete(%{unique_token: ""}) do
      raise GRPC.RPCError,
        status: :invalid_argument,
        message: "Missing argument: unique_token"
    end

    defp delete(%{target_id: target_id, requester_id: _requester_id}) do
      DB.delete(:deployment_targets, fn target -> target.id == target_id end)
      DB.delete(:deployment_secrets, fn secret -> secret.dt_id == target_id end)

      API.DeleteResponse.new(target_id: target_id)
    end

    defp upsert_target(request, target_id, secret_id, history \\ []) do
      if request.secret do
        DB.upsert(:deployment_secrets, %{
          id: secret_id,
          name: "dt.#{target_id}",
          dt_id: target_id,
          api_model: secret_api_model(target_id, secret_id, request)
        })
      end

      res =
        DB.upsert(:deployment_targets, %{
          id: target_id,
          project_id: request.target.project_id,
          name: request.target.name,
          unique_token: request.unique_token,
          api_model: target_api_model(target_id, request),
          history: history
        })

      res
    end

    defp target_api_model(target_id, request) do
      timestamp = Map.from_struct(StubTime.now())

      request.target
      |> Map.merge(%{
        id: target_id,
        state: :USABLE,
        created_by: request.requester_id,
        updated_by: request.requester_id,
        created_at: timestamp,
        updated_at: timestamp
      })
      |> Map.delete(:last_deployment)
      |> Util.Proto.deep_new!(API.DeploymentTarget)
    end

    defp secret_api_model(target_id, secret_id, request) do
      {:ok, secret_data} = SecretKeys.decrypt(request.secret)
      timestamp = Map.from_struct(StubTime.now())

      Util.Proto.deep_new!(InternalApi.Secrethub.Secret,
        metadata: %{
          id: secret_id,
          name: "dt.#{target_id}",
          org_id: request.target.organization_id,
          created_by: request.requester_id,
          updated_by: request.requester_id,
          created_at: timestamp,
          updated_at: timestamp
        },
        data: Util.Proto.to_map!(secret_data),
        dt_config: %{deployment_target_id: target_id}
      )
    end

    defp valid?(target, target_params, secret_params) do
      valid_target? = validate_target(target, target_params)
      valid_secret? = validate_secret(%API.EncryptedSecretData{}, secret_params)
      valid_target? && valid_secret?
    end

    defp validate_target(target, params) do
      fields = ~w(id name description url organization_id project_id)a
      required = ~w(name organization_id project_id)a

      valid_fields? =
        {target, Enum.into(fields, %{}, &{&1, :string})}
        |> Ecto.Changeset.cast(params, fields)
        |> Ecto.Changeset.validate_required(required)
        |> (& &1.valid?).()

      valid_subject_rules? = Enum.all?(params.subject_rules, &validate_subject_rule/1)
      valid_object_rules? = Enum.all?(params.object_rules, &validate_object_rule/1)

      valid_fields? && valid_object_rules? && valid_subject_rules?
    end

    defp validate_subject_rule(params) do
      {API.SubjectRule.new(), %{type: :integer, subject_id: :string}}
      |> Ecto.Changeset.cast(params, [:type, :subject_id])
      |> Ecto.Changeset.validate_inclusion(:type, [0, 1, 3, 4])
      |> validate_subject_id()
      |> (& &1.valid?).()
    end

    defp validate_subject_id(changeset) do
      if Ecto.Changeset.get_field(changeset, :type) < 3,
        do: Ecto.Changeset.validate_required(changeset, [:subject_id]),
        else: changeset
    end

    defp validate_object_rule(params) do
      {API.ObjectRule.new(), %{type: :integer, match_mode: :integer, pattern: :string}}
      |> Ecto.Changeset.cast(params, [:type, :match_mode, :pattern])
      |> Ecto.Changeset.validate_inclusion(:type, 0..2)
      |> Ecto.Changeset.validate_inclusion(:match_mode, 0..2)
      |> validate_pattern()
      |> (& &1.valid?).()
    end

    defp validate_pattern(changeset) do
      case Ecto.Changeset.get_field(changeset, :match_mode) do
        0 -> changeset
        _ -> Ecto.Changeset.validate_required(changeset, [:pattern])
      end
    end

    defp validate_secret(_secret, nil), do: true

    defp validate_secret(secret, params) do
      fields = ~w(key_id aes256_key init_vector payload)a

      {secret, Enum.into(fields, %{}, &{&1, :string})}
      |> Ecto.Changeset.cast(params, fields)
      |> Ecto.Changeset.validate_required(fields)
      |> (& &1.valid?).()
    end

    defp transformations do
      %{
        API.SubjectRule.Type => fn _name, value -> value end,
        API.ObjectRule.Type => fn _name, value -> value end,
        API.ObjectRule.Mode => fn _name, value -> value end
      }
    end
  end
end
