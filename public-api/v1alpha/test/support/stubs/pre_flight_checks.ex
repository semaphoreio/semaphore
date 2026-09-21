defmodule Support.Stubs.PreFlightChecks do
  alias Support.Stubs.DB
  alias InternalApi.PreFlightChecksHub, as: API

  # This makes it easier to test
  @timestamp 1_668_202_871

  def init do
    DB.add_table(:pre_flight_checks, [:id, :level, :organization_id, :project_id, :model])

    __MODULE__.Grpc.init()
  end

  def create_for_organization(org_id, params \\ []) do
    DB.upsert(:pre_flight_checks, %{
      id: {:organization, org_id},
      level: params[:level] || :ORGANIZATION,
      organization_id: org_id,
      project_id: "",
      model:
        API.OrganizationPFC.new(
          commands: params[:commands] || [],
          secrets: params[:secrets] || [],
          agent: agent(params[:agent]),
          requester_id: params[:requester_id] || "",
          created_at: Google.Protobuf.Timestamp.new(seconds: @timestamp),
          updated_at: Google.Protobuf.Timestamp.new(seconds: @timestamp)
        )
    })
  end

  def create_for_project(org_id, project_id, params \\ []) do
    DB.upsert(:pre_flight_checks, %{
      id: {:project, project_id},
      level: params[:level] || :PROJECT,
      organization_id: org_id,
      project_id: project_id,
      model:
        API.ProjectPFC.new(
          commands: params[:commands] || [],
          secrets: params[:secrets] || [],
          agent: agent(params[:agent]),
          requester_id: params[:requester_id] || "",
          created_at: Google.Protobuf.Timestamp.new(seconds: @timestamp),
          updated_at: Google.Protobuf.Timestamp.new(seconds: @timestamp)
        )
    })
  end

  def find_for_organization(org_id), do: DB.find(:pre_flight_checks, {:organization, org_id})

  def find_for_project(project_id), do: DB.find(:pre_flight_checks, {:project, project_id})

  defp agent(nil), do: nil

  defp agent(agent = %API.Agent{}), do: agent

  defp agent(agent),
    do: API.Agent.new(machine_type: agent[:machine_type] || "", os_image: agent[:os_image] || "")

  defmodule Grpc do
    alias Support.Stubs.PreFlightChecks, as: PFC

    def init do
      GrpcMock.stub(PreFlightChecksMock, :describe, &__MODULE__.describe/2)
      GrpcMock.stub(PreFlightChecksMock, :apply, &__MODULE__.apply/2)
      GrpcMock.stub(PreFlightChecksMock, :destroy, &__MODULE__.destroy/2)
    end

    def describe(%{project_id: project_id}, _) when project_id != "" do
      case PFC.find_for_project(project_id) do
        nil ->
          API.DescribeResponse.new(status: status(:NOT_FOUND, "Pre-flight checks not found"))

        record ->
          API.DescribeResponse.new(
            status: status(:OK),
            pre_flight_checks: API.PreFlightChecks.new(project_pfc: record.model)
          )
      end
    end

    def describe(req, _) do
      case PFC.find_for_organization(req.organization_id) do
        nil ->
          API.DescribeResponse.new(status: status(:NOT_FOUND, "Pre-flight checks not found"))

        record ->
          API.DescribeResponse.new(
            status: status(:OK),
            pre_flight_checks: API.PreFlightChecks.new(organization_pfc: record.model)
          )
      end
    end

    def apply(req = %{project_id: project_id}, _) when project_id != "" do
      case req.pre_flight_checks do
        %{project_pfc: pfc = %{commands: [_ | _]}} ->
          record =
            PFC.create_for_project(req.organization_id, project_id,
              level: level(req),
              commands: pfc.commands,
              secrets: pfc.secrets,
              agent: pfc.agent,
              requester_id: req.requester_id
            )

          API.ApplyResponse.new(
            status: status(:OK),
            pre_flight_checks: API.PreFlightChecks.new(project_pfc: record.model)
          )

        _ ->
          API.ApplyResponse.new(status: status(:INVALID_ARGUMENT, "Commands cannot be empty"))
      end
    end

    def apply(req, _) do
      case req.pre_flight_checks do
        %{organization_pfc: pfc = %{commands: [_ | _]}} ->
          record =
            PFC.create_for_organization(req.organization_id,
              level: level(req),
              commands: pfc.commands,
              secrets: pfc.secrets,
              agent: pfc.agent,
              requester_id: req.requester_id
            )

          API.ApplyResponse.new(
            status: status(:OK),
            pre_flight_checks: API.PreFlightChecks.new(organization_pfc: record.model)
          )

        _ ->
          API.ApplyResponse.new(status: status(:INVALID_ARGUMENT, "Commands cannot be empty"))
      end
    end

    def destroy(%{project_id: project_id}, _) when project_id != "" do
      DB.delete(:pre_flight_checks, {:project, project_id})
      API.DestroyResponse.new(status: status(:OK))
    end

    def destroy(req, _) do
      DB.delete(:pre_flight_checks, {:organization, req.organization_id})
      API.DestroyResponse.new(status: status(:OK))
    end

    defp level(%{level: level}) when is_atom(level), do: level

    defp level(%{level: level}), do: API.PFCLevel.key(level)

    defp status(code, message \\ "") do
      InternalApi.Status.new(
        code: Google.Rpc.Code.value(code),
        message: message
      )
    end
  end
end
