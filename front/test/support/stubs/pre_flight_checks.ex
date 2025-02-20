defmodule Support.Stubs.PreFlightChecks do
  alias Support.Stubs.{DB, UUID}
  alias Support.Stubs.Time, as: StubTime

  def init do
    DB.add_table(:organization_pfcs, [:id, :organization_id, :api_model])
    DB.add_table(:project_pfcs, [:id, :project_id, :api_model])

    __MODULE__.Grpc.init()
  end

  def create(:organization_pfc, organization_id, api_model) do
    DB.insert(:organization_pfcs, %{
      id: UUID.gen(),
      organization_id: organization_id,
      api_model:
        api_model
        |> Map.put(:created_at, Map.from_struct(StubTime.now()))
        |> Map.put(:updated_at, Map.from_struct(StubTime.now()))
    })
  end

  def create(:project_pfc, project_id, api_model) do
    DB.insert(:project_pfcs, %{
      id: UUID.gen(),
      project_id: project_id,
      api_model:
        api_model
        |> Map.put(:created_at, Map.from_struct(StubTime.now()))
        |> Map.put(:updated_at, Map.from_struct(StubTime.now()))
    })
  end

  defmodule Grpc do
    alias InternalApi.PreFlightChecksHub, as: API

    def init do
      GrpcMock.stub(PreFlightChecksMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(PreFlightChecksMock, :apply, &__MODULE__.apply/2)
      GrpcMock.stub(PreFlightChecksMock, :destroy, &__MODULE__.destroy/2)
    end

    def describe(request = %API.DescribeRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> describe()

    def apply(request = %API.ApplyRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> apply()

    def destroy(request = %API.DestroyRequest{}, _stream),
      do: request |> Util.Proto.to_map!() |> destroy()

    defp describe(%{level: :ORGANIZATION, organization_id: nil}),
      do: invalid_argument_response(API.DescribeResponse, "organization_id can't be blank")

    defp describe(request = %{level: :ORGANIZATION}) do
      case DB.find_by(:organization_pfcs, :organization_id, request.organization_id) do
        nil -> not_found_response(API.DescribeResponse, :organization, request.organization_id)
        pfc -> ok_response_with_payload(API.DescribeResponse, organization_pfc: pfc.api_model)
      end
    end

    defp describe(%{level: :PROJECT, project_id: nil}),
      do: invalid_argument_response(API.DescribeResponse, "project_id can't be blank")

    defp describe(request = %{level: :PROJECT}) do
      case DB.find_by(:project_pfcs, :project_id, request.project_id) do
        nil -> not_found_response(API.DescribeResponse, :project, request.project_id)
        pfc -> ok_response_with_payload(API.DescribeResponse, project_pfc: pfc.api_model)
      end
    end

    defp apply(request) do
      case validate_request(request) do
        {:ok, request} ->
          ok_response_with_payload(API.ApplyResponse, do_apply(request))

        {:error, message} ->
          invalid_argument_response(API.ApplyResponse, message)
      end
    end

    defp destroy(request = %{level: :ORGANIZATION}) do
      if pfc = DB.find_by(:organization_pfcs, :organization_id, request.organization_id),
        do: DB.delete(:organization_pfcs, pfc.id)

      ok_response(API.DestroyResponse)
    end

    defp destroy(request = %{level: :PROJECT}) do
      if pfc = DB.find_by(:project_pfcs, :project_id, request.project_id),
        do: DB.delete(:project_pfcs, pfc.id)

      ok_response(API.DestroyResponse)
    end

    defp do_apply(request = %{level: :ORGANIZATION}) do
      new_model_params =
        request.pre_flight_checks.organization_pfc
        |> Map.take(~w(commands secrets)a)
        |> Map.put(:requester_id, request.requester_id)

      organization_id = request.organization_id
      timestamp = %{seconds: DateTime.utc_now() |> DateTime.to_unix(), nanos: 0}

      entry =
        if pfc = DB.find_by(:organization_pfcs, :organization_id, organization_id) do
          DB.update(:organization_pfcs, %{
            pfc
            | api_model:
                pfc.api_model
                |> Map.merge(new_model_params)
                |> Map.put(:updated_at, timestamp)
          })
        else
          DB.insert(:organization_pfcs, %{
            id: UUID.gen(),
            organization_id: organization_id,
            api_model:
              new_model_params
              |> Map.put(:created_at, timestamp)
              |> Map.put(:updated_at, timestamp)
          })
        end

      [organization_pfc: entry.api_model]
    end

    defp do_apply(request = %{level: :PROJECT}) do
      new_model_params =
        request.pre_flight_checks.project_pfc
        |> Map.take(~w(commands secrets agent)a)
        |> Map.put(:requester_id, request.requester_id)

      project_id = request.project_id
      timestamp = %{seconds: DateTime.utc_now() |> DateTime.to_unix(), nanos: 0}

      entry =
        if pfc = DB.find_by(:project_pfcs, :project_id, project_id) do
          DB.update(:project_pfcs, %{
            pfc
            | api_model:
                pfc.api_model
                |> Map.merge(new_model_params)
                |> case do
                  %{agent: nil} = model -> Map.delete(model, :agent)
                  %{agent: _agent} = model -> model
                end
                |> Map.put(:updated_at, timestamp)
          })
        else
          DB.insert(:project_pfcs, %{
            id: UUID.gen(),
            project_id: project_id,
            api_model:
              new_model_params
              |> case do
                %{agent: nil} = model -> Map.delete(model, :agent)
                %{agent: _agent} = model -> model
              end
              |> Map.put(:created_at, timestamp)
              |> Map.put(:updated_at, timestamp)
          })
        end

      [project_pfc: entry.api_model]
    end

    defp validate_request(request = %{level: :ORGANIZATION}) do
      validate(request, [
        &validate_string(&1, :organization_id),
        &validate_string(&1, :requester_id),
        &validate_commands(&1, :organization_pfc)
      ]) || {:ok, request}
    end

    defp validate_request(request = %{level: :PROJECT}) do
      validate(request, [
        &validate_string(&1, :organization_id),
        &validate_string(&1, :project_id),
        &validate_string(&1, :requester_id),
        &validate_commands(&1, :project_pfc),
        &validate_agent/1
      ]) || {:ok, request}
    end

    defp validate(container, validators) do
      Enum.find_value(validators, & &1.(container))
    end

    defp validate_commands(request, subcontainer) do
      commands =
        request
        |> Map.get(:pre_flight_checks, %{})
        |> Map.get(subcontainer, %{})
        |> Map.get(:commands, [])

      if length(commands) < 1,
        do: {:error, "commands should have at least 1 item(s)"}
    end

    defp validate_agent(request) do
      agent =
        request
        |> Map.get(:pre_flight_checks, %{})
        |> Map.get(:project_pfc, %{})
        |> Map.get(:agent)

      if agent do
        validate(agent, [
          &validate_string(&1, :machine_type)
        ])
      end
    end

    defp validate_string(container, field_name) do
      if String.length(container[field_name] || "") < 1,
        do: {:error, "#{field_name} can't be blank"}
    end

    defp ok_response_with_payload(response_module, params) do
      %{pre_flight_checks: Map.new(params)}
      |> Map.put(:status, %{code: :OK})
      |> Util.Proto.deep_new!(response_module)
    end

    defp ok_response(response_module, params \\ []) do
      Map.new(params)
      |> Map.put(:status, %{code: :OK})
      |> Util.Proto.deep_new!(response_module)
    end

    defp invalid_argument_response(response_module, message) do
      Util.Proto.deep_new!(response_module, %{
        status: %{code: :INVALID_ARGUMENT, message: message}
      })
    end

    defp not_found_response(response_module, entity, entity_id) do
      message = "Pre-flight check for #{entity} \"#{entity_id}\" was not found"
      Util.Proto.deep_new!(response_module, status: %{code: :NOT_FOUND, message: message})
    end
  end
end
