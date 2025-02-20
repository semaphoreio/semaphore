defmodule PreFlightChecks.DestroyTraces.DestroyTraceQueriesTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias PreFlightChecks.DestroyTraces.DestroyTraceQueries
  alias PreFlightChecks.DestroyTraces.DestroyTrace

  alias InternalApi.PreFlightChecksHub.DestroyRequest
  alias InternalApi.Organization.OrganizationDeleted
  alias InternalApi.Projecthub.ProjectDeleted

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(PreFlightChecks.EctoRepo)
  end

  describe "DestroyTraceQueries.register/1 for requests" do
    test "when level = ORGANIZATION then inserts a new record in the table" do
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert {:ok,
              %DestroyTrace{
                organization_id: ^organization_id,
                requester_id: ^requester_id,
                level: :ORGANIZATION,
                status: :RECEIVED
              }} =
               DestroyTraceQueries.register(
                 DestroyRequest.new(
                   level: :ORGANIZATION,
                   organization_id: organization_id,
                   requester_id: requester_id
                 )
               )
    end

    test "when level = PROJECT then inserts a new record in the table" do
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert {:ok,
              %DestroyTrace{
                project_id: ^project_id,
                requester_id: ^requester_id,
                level: :PROJECT,
                status: :RECEIVED
              }} =
               DestroyTraceQueries.register(
                 DestroyRequest.new(
                   level: :PROJECT,
                   project_id: project_id,
                   requester_id: requester_id
                 )
               )
    end
  end

  describe "DestroyTraceQueries.register/1 for events" do
    test "when OrganizationDeleted received then inserts a new record in the table" do
      organization_id = UUID.uuid4()

      assert {:ok,
              %DestroyTrace{
                organization_id: ^organization_id,
                requester_id: "organization_deleted_event",
                level: :ORGANIZATION,
                status: :RECEIVED
              }} =
               DestroyTraceQueries.register(
                 OrganizationDeleted.new(
                   org_id: organization_id,
                   timestamp:
                     Google.Protobuf.Timestamp.new(
                       seconds: DateTime.utc_now() |> DateTime.to_unix()
                     )
                 )
               )
    end

    test "when level = PROJECT then inserts a new record in the table" do
      organization_id = UUID.uuid4()
      project_id = UUID.uuid4()

      assert {:ok,
              %DestroyTrace{
                organization_id: ^organization_id,
                project_id: ^project_id,
                requester_id: "project_deleted_event",
                level: :PROJECT,
                status: :RECEIVED
              }} =
               DestroyTraceQueries.register(
                 ProjectDeleted.new(
                   org_id: organization_id,
                   project_id: project_id,
                   timestamp:
                     Google.Protobuf.Timestamp.new(
                       seconds: DateTime.utc_now() |> DateTime.to_unix()
                     )
                 )
               )
    end
  end

  describe "DestroyTraceQueries.resolve_success/1" do
    test "when level = ORGANIZATION then updates a record in the table" do
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert {:ok, trace} =
               DestroyTraceQueries.register(
                 DestroyRequest.new(
                   level: :ORGANIZATION,
                   organization_id: organization_id,
                   requester_id: requester_id
                 )
               )

      assert {:ok,
              %DestroyTrace{
                organization_id: ^organization_id,
                requester_id: ^requester_id,
                level: :ORGANIZATION,
                status: :SUCCESS
              }} = DestroyTraceQueries.resolve_success(trace)
    end

    test "when level = PROJECT then updates a record in the table" do
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert {:ok, trace} =
               DestroyTraceQueries.register(
                 DestroyRequest.new(
                   level: :ORGANIZATION,
                   project_id: project_id,
                   requester_id: requester_id
                 )
               )

      assert {:ok,
              %DestroyTrace{
                project_id: ^project_id,
                requester_id: ^requester_id,
                level: :ORGANIZATION,
                status: :SUCCESS
              }} = DestroyTraceQueries.resolve_success(trace)
    end
  end

  describe "DestroyTraceQueries.resolve_failure/1" do
    test "when level = ORGANIZATION then updates a record in the table" do
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert {:ok, trace} =
               DestroyTraceQueries.register(
                 DestroyRequest.new(
                   level: :ORGANIZATION,
                   organization_id: organization_id,
                   requester_id: requester_id
                 )
               )

      assert {:ok,
              %DestroyTrace{
                organization_id: ^organization_id,
                requester_id: ^requester_id,
                level: :ORGANIZATION,
                status: :FAILURE
              }} = DestroyTraceQueries.resolve_failure(trace)
    end

    test "when level = PROJECT then updates a record in the table" do
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert {:ok, trace} =
               DestroyTraceQueries.register(
                 DestroyRequest.new(
                   level: :ORGANIZATION,
                   project_id: project_id,
                   requester_id: requester_id
                 )
               )

      assert {:ok,
              %DestroyTrace{
                project_id: ^project_id,
                requester_id: ^requester_id,
                level: :ORGANIZATION,
                status: :FAILURE
              }} = DestroyTraceQueries.resolve_failure(trace)
    end
  end
end
