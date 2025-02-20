defmodule Front.Models.PreFlightChecksTest do
  use ExUnit.Case, async: false

  alias Front.Models.PreFlightChecks, as: Model
  alias InternalApi.PreFlightChecksHub, as: API
  alias Support.Stubs

  @moduletag :pre_flight_checks

  setup_all [
    :setup_org_pfc_params,
    :setup_proj_pfc_params,
    :setup_org_pfc_model,
    :setup_proj_pfc_model
  ]

  setup [
    :setup_organization_pfc,
    :setup_project_pfc
  ]

  describe "OrganizationPFC.from_api/1" do
    test "when data contains all the fields then returns the complete model",
         context do
      params = context[:org_pfc_params]

      expected_model = %Model.OrganizationPFC{
        commands: params[:commands],
        secrets: params[:secrets],
        requester_id: params[:requester_id],
        updated_at: params[:updated_at].seconds |> DateTime.from_unix!()
      }

      assert ^expected_model =
               params
               |> Util.Proto.deep_new!(API.OrganizationPFC)
               |> Model.OrganizationPFC.from_api()
    end

    test "when data doesn't contain requester_id and updated_at " <>
           "then returns model with empty requester_id and updated_at = nil",
         context do
      params = context[:org_pfc_params] |> Map.drop([:requester_id, :updated_at])

      expected_model = %Model.OrganizationPFC{
        commands: params[:commands],
        secrets: params[:secrets],
        requester_id: "",
        updated_at: nil
      }

      assert ^expected_model =
               params
               |> Util.Proto.deep_new!(API.OrganizationPFC)
               |> Model.OrganizationPFC.from_api()
    end

    test "when data is nil then returns empty model",
         _context do
      expected_model = %Model.OrganizationPFC{
        commands: [],
        secrets: [],
        requester_id: "",
        updated_at: nil
      }

      assert ^expected_model =
               %{}
               |> Util.Proto.deep_new!(API.OrganizationPFC)
               |> Model.OrganizationPFC.from_api()
    end
  end

  describe "OrganizationPFC.to_api/1" do
    test "converts model to API structure", context do
      params = context[:org_pfc_params]

      expected_api = %{
        commands: params[:commands],
        secrets: params[:secrets]
      }

      assert ^expected_api = Model.OrganizationPFC.to_api(Model.OrganizationPFC.new(params))
    end
  end

  describe "ProjectPFC.from_api/1" do
    test "when data contains all the fields then returns the complete model",
         context do
      params = context[:proj_pfc_params]

      expected_model = %Model.ProjectPFC{
        commands: params[:commands],
        secrets: params[:secrets],
        has_custom_agent: true,
        agent: %Model.AgentConfig{
          machine_type: params[:agent][:machine_type],
          os_image: params[:agent][:os_image]
        },
        requester_id: params[:requester_id],
        updated_at: params[:updated_at].seconds |> DateTime.from_unix!()
      }

      assert ^expected_model =
               params
               |> Util.Proto.deep_new!(API.ProjectPFC)
               |> Util.Proto.to_map!()
               |> Model.ProjectPFC.from_api()
    end

    test "when data doesn't contain requester_id and updated_at " <>
           "then returns model with empty requester_id and updated_at = nil",
         context do
      params = context[:proj_pfc_params] |> Map.drop([:requester_id, :updated_at])

      expected_model = %Model.ProjectPFC{
        commands: params[:commands],
        secrets: params[:secrets],
        has_custom_agent: true,
        agent: %Model.AgentConfig{
          machine_type: params[:agent][:machine_type],
          os_image: params[:agent][:os_image]
        },
        requester_id: "",
        updated_at: nil
      }

      assert ^expected_model =
               params
               |> Util.Proto.deep_new!(API.ProjectPFC)
               |> Util.Proto.to_map!()
               |> Model.ProjectPFC.from_api()
    end

    test "when data doesn't contain agent " <>
           "then returns model with empty agent model",
         context do
      params = context[:proj_pfc_params] |> Map.drop([:agent])

      expected_model = %Model.ProjectPFC{
        commands: params[:commands],
        secrets: params[:secrets],
        has_custom_agent: false,
        agent: %Model.AgentConfig{
          machine_type: "",
          os_image: ""
        },
        requester_id: params[:requester_id],
        updated_at: params[:updated_at].seconds |> DateTime.from_unix!()
      }

      assert ^expected_model =
               params
               |> Util.Proto.deep_new!(API.ProjectPFC)
               |> Util.Proto.to_map!()
               |> Model.ProjectPFC.from_api()
    end

    test "when data is nil then returns empty model",
         _context do
      expected_model = %Model.ProjectPFC{
        commands: [],
        secrets: [],
        has_custom_agent: false,
        agent: %Model.AgentConfig{
          machine_type: "",
          os_image: ""
        },
        requester_id: "",
        updated_at: nil
      }

      assert ^expected_model =
               %{}
               |> Util.Proto.deep_new!(API.ProjectPFC)
               |> Util.Proto.to_map!()
               |> Model.ProjectPFC.from_api()
    end
  end

  describe "ProjectPFC.to_api/1" do
    test "converts model to API structure", context do
      params = context[:proj_pfc_params]

      expected_api = %{
        commands: params[:commands],
        secrets: params[:secrets],
        agent: %{
          machine_type: params[:agent][:machine_type],
          os_image: params[:agent][:os_image]
        }
      }

      assert ^expected_api = Model.ProjectPFC.to_api(Model.ProjectPFC.from_api(params))
    end

    test "converts model without agent config to API structure", context do
      params = context[:proj_pfc_params] |> Map.put(:agent, nil)

      expected_api = %{
        commands: params[:commands],
        secrets: params[:secrets]
      }

      assert ^expected_api = Model.ProjectPFC.to_api(Model.ProjectPFC.from_api(params))
    end

    test "converts agent config when has_custom_agent is false", context do
      model = context[:proj_pfc_model]

      expected_api = %{
        commands: model.commands,
        secrets: model.secrets,
        agent: %{
          machine_type: model.agent.machine_type,
          os_image: model.agent.os_image
        }
      }

      assert ^expected_api = Model.ProjectPFC.to_api(model)
    end

    test "ignores agent config when has_custom_agent is false", context do
      model = context[:proj_pfc_model] |> Map.put(:has_custom_agent, false)

      expected_api = %{
        commands: model.commands,
        secrets: model.secrets
      }

      assert ^expected_api = Model.ProjectPFC.to_api(model)
    end
  end

  describe "describe_for_organization/1" do
    test "when organization has pre-flight checks configured " <>
           "then returns the model",
         context do
      organization_id = context[:organization_id]
      entry = Stubs.DB.find_by(:organization_pfcs, :organization_id, organization_id)
      model = Model.OrganizationPFC.from_api(entry.api_model)

      assert {:ok, ^model} = Model.describe_for_organization(context[:organization_id])
    end

    test "when organization has no pre-flight checks configured " <>
           "then returns error with status",
         _context do
      organization_id = UUID.uuid4()
      message = "Pre-flight check for organization \"#{organization_id}\" was not found"

      assert {:error, %{code: :NOT_FOUND, message: ^message}} =
               Model.describe_for_organization(organization_id)
    end

    test "when organization_id is nil then returns error" do
      assert {:error, %RuntimeError{message: message}} = Model.describe_for_organization(nil)
      assert message =~ "organization_id"
    end
  end

  describe "apply_for_organization/3" do
    test "when organization has pre-flight checks configured " <>
           "then returns the updated model",
         context do
      organization_id = context[:organization_id]
      requester_id = UUID.uuid4()
      model = context[:org_pfc_model]

      old_entry = Stubs.DB.find_by(:organization_pfcs, :organization_id, organization_id)

      assert {:ok, new_model} = Model.apply_for_organization(organization_id, requester_id, model)
      assert entry = Stubs.DB.find_by(:organization_pfcs, :organization_id, organization_id)

      assert ^new_model = Model.OrganizationPFC.from_api(entry.api_model)
      assert ^requester_id = new_model.requester_id
      assert DateTime.to_unix(new_model.updated_at) >= old_entry.api_model.updated_at.seconds
    end

    test "when organization has no pre-flight checks configured " <>
           "then returns a newly created model",
         context do
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      model = context[:org_pfc_model]

      fingerprint = Stubs.Time.now()

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:organization_pfcs, :organization_id, organization_id)
      end

      assert {:ok, new_model} = Model.apply_for_organization(organization_id, requester_id, model)
      assert entry = Stubs.DB.find_by(:organization_pfcs, :organization_id, organization_id)

      assert ^new_model = Model.OrganizationPFC.from_api(entry.api_model)
      assert ^requester_id = new_model.requester_id
      assert DateTime.to_unix(new_model.updated_at) >= fingerprint.seconds
    end

    test "when model is not a valid struct then returns an error",
         context do
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      model = context[:org_pfc_model] |> Map.from_struct()

      assert {:error, %Protocol.UndefinedError{value: {:organization_pfc, nil}}} =
               Model.apply_for_organization(organization_id, requester_id, model)
    end

    test "when model has empty commands then returns an error",
         context do
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      model = context[:org_pfc_model] |> Map.put(:commands, [])

      assert {:error, %{code: :INVALID_ARGUMENT, message: message}} =
               Model.apply_for_organization(organization_id, requester_id, model)

      assert message =~ "commands"
    end

    test "when organization_id is nil then returns error", context do
      assert {:error, %RuntimeError{message: message}} =
               Model.apply_for_organization(nil, context[:requester_id], context[:org_pfc_model])

      assert message =~ "organization_id"
    end

    test "when requester_id is nil then returns error", context do
      assert {:error, %RuntimeError{message: message}} =
               Model.apply_for_organization(
                 context[:organization_id],
                 nil,
                 context[:org_pfc_model]
               )

      assert message =~ "requester_id"
    end
  end

  describe "destroy_for_organization/2" do
    test "when organization has pre-flight checks configured " <>
           "then removes pre-flight check and returns OK response",
         context do
      organization_id = context[:organization_id]
      requester_id = UUID.uuid4()

      assert :ok = Model.destroy_for_organization(organization_id, requester_id)

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:organization_pfcs, :organization_id, organization_id)
      end
    end

    test "when organization has no pre-flight checks configured " <>
           "then returns OK response",
         _context do
      organization_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:organization_pfcs, :organization_id, organization_id)
      end

      assert :ok = Model.destroy_for_organization(organization_id, requester_id)

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:organization_pfcs, :organization_id, organization_id)
      end
    end

    test "when organization_id is nil then returns error", context do
      assert {:error, %RuntimeError{message: message}} =
               Model.destroy_for_organization(nil, context[:requester_id])

      assert message =~ "organization_id"
    end

    test "when requester_id is nil then returns error", context do
      assert {:error, %RuntimeError{message: message}} =
               Model.destroy_for_organization(context[:organization_id], nil)

      assert message =~ "requester_id"
    end
  end

  describe "describe_for_project/1" do
    test "when project has pre-flight checks configured " <>
           "then returns the model",
         context do
      project_id = context[:project_id]
      entry = Stubs.DB.find_by(:project_pfcs, :project_id, project_id)
      model = Model.ProjectPFC.from_api(entry.api_model)

      assert {:ok, ^model} = Model.describe_for_project(context[:project_id])
    end

    test "when project has no pre-flight checks configured " <>
           "then returns error with status",
         _context do
      project_id = UUID.uuid4()
      message = "Pre-flight check for project \"#{project_id}\" was not found"

      assert {:error, %{code: :NOT_FOUND, message: ^message}} =
               Model.describe_for_project(project_id)
    end

    test "when project_id is nil then returns error" do
      assert {:error, %RuntimeError{message: message}} = Model.describe_for_project(nil)
      assert message =~ "project_id"
    end
  end

  describe "apply_for_project/3" do
    test "when project has pre-flight checks configured " <>
           "then returns the updated model",
         context do
      organization_id = context[:organization_id]
      project_id = context[:project_id]
      requester_id = UUID.uuid4()
      model = context[:proj_pfc_model]

      old_entry = Stubs.DB.find_by(:project_pfcs, :project_id, project_id)

      assert {:ok, new_model} =
               Model.apply_for_project(organization_id, project_id, requester_id, model)

      assert entry = Stubs.DB.find_by(:project_pfcs, :project_id, project_id)

      assert ^new_model = Model.ProjectPFC.from_api(entry.api_model)
      assert ^requester_id = new_model.requester_id
      assert DateTime.to_unix(new_model.updated_at) >= old_entry.api_model.updated_at.seconds
    end

    test "when project has no pre-flight checks configured " <>
           "then returns a newly created model",
         context do
      organization_id = UUID.uuid4()
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      model = context[:proj_pfc_model]

      fingerprint = Stubs.Time.now()

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:project_pfcs, :project_id, project_id)
      end

      assert {:ok, new_model} =
               Model.apply_for_project(organization_id, project_id, requester_id, model)

      assert entry = Stubs.DB.find_by(:project_pfcs, :project_id, project_id)

      assert ^new_model = Model.ProjectPFC.from_api(entry.api_model)
      assert ^requester_id = new_model.requester_id
      assert DateTime.to_unix(new_model.updated_at) >= fingerprint.seconds
    end

    test "when model is not a valid struct then returns an error",
         context do
      organization_id = UUID.uuid4()
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      model = context[:org_pfc_model] |> Map.from_struct()

      assert {:error, %Protocol.UndefinedError{value: {:project_pfc, nil}}} =
               Model.apply_for_project(organization_id, project_id, requester_id, model)
    end

    test "when model has empty commands then returns an error",
         context do
      organization_id = UUID.uuid4()
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      model = context[:proj_pfc_model] |> Map.put(:commands, [])

      assert {:error, %{code: :INVALID_ARGUMENT, message: message}} =
               Model.apply_for_project(organization_id, project_id, requester_id, model)

      assert message =~ "commands"
    end

    test "when model has empty agent's machine type then returns an error",
         context do
      organization_id = UUID.uuid4()
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      model =
        context[:proj_pfc_model]
        |> Map.update!(:agent, &Map.put(&1, :machine_type, ""))

      assert {:error, %{code: :INVALID_ARGUMENT, message: message}} =
               Model.apply_for_project(organization_id, project_id, requester_id, model)

      assert message =~ "machine_type"
    end

    test "when model has empty agent's OS image " <>
           "then returns a newly created model",
         context do
      organization_id = UUID.uuid4()
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()
      fingerprint = Stubs.Time.now()

      model =
        context[:proj_pfc_model]
        |> Map.update!(:agent, &Map.put(&1, :os_image, ""))

      assert {:ok, new_model} =
               Model.apply_for_project(organization_id, project_id, requester_id, model)

      assert entry = Stubs.DB.find_by(:project_pfcs, :project_id, project_id)

      assert ^new_model = Model.ProjectPFC.from_api(entry.api_model)
      assert ^requester_id = new_model.requester_id
      assert DateTime.to_unix(new_model.updated_at) >= fingerprint.seconds
    end
  end

  describe "destroy_for_project/2" do
    test "when project has pre-flight checks configured " <>
           "then removes pre-flight check and returns OK response",
         context do
      project_id = context[:project_id]
      requester_id = UUID.uuid4()

      assert :ok = Model.destroy_for_project(project_id, requester_id)

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:project_pfcs, :project_id, project_id)
      end
    end

    test "when project has no pre-flight checks configured " <>
           "then returns OK response",
         _context do
      project_id = UUID.uuid4()
      requester_id = UUID.uuid4()

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:project_pfcs, :project_id, project_id)
      end

      assert :ok = Model.destroy_for_project(project_id, requester_id)

      assert_raise Support.Stubs.DB.NotFoundError, fn ->
        Stubs.DB.find_by!(:project_pfcs, :project_id, project_id)
      end
    end

    test "when project_id is nil then returns error", context do
      assert {:error, %RuntimeError{message: message}} =
               Model.destroy_for_project(nil, context[:requester_id])

      assert message =~ "project_id"
    end

    test "when requester_id is nil then returns error", context do
      assert {:error, %RuntimeError{message: message}} =
               Model.destroy_for_project(context[:project_id], nil)

      assert message =~ "requester_id"
    end
  end

  defp setup_org_pfc_params(_context) do
    {:ok,
     org_pfc_params: %{
       requester_id: UUID.uuid4(),
       commands: [
         "checkout",
         "npm install",
         "npm run-script custom_security_check -- --some-option some-value"
       ],
       secrets: [
         "SECRET_TAG_3",
         "SECRET_TAG_4"
       ],
       created_at: Stubs.Time.now() |> Map.from_struct(),
       updated_at: Stubs.Time.now() |> Map.from_struct()
     }}
  end

  defp setup_proj_pfc_params(_context) do
    {:ok,
     proj_pfc_params: %{
       requester_id: UUID.uuid4(),
       commands: [
         "checkout",
         "mix local.hex --force && local.rebar --force",
         "mix deps.get && mix.compile",
         "mix custom_security_check --some-option some-value"
       ],
       secrets: [
         "SECRET_TAG_1",
         "SECRET_TAG_2"
       ],
       agent: %{
         machine_type: "e1-standard-2",
         os_image: "ubuntu1804"
       },
       created_at: Stubs.Time.now() |> Map.from_struct(),
       updated_at: Stubs.Time.now() |> Map.from_struct()
     }}
  end

  defp setup_org_pfc_model(_context) do
    {:ok,
     org_pfc_model: %Model.OrganizationPFC{
       commands: [
         "checkout",
         "mix local.hex --force && local.rebar --force",
         "mix deps.get && mix.compile",
         "mix custom_security_check --some-option some-value"
       ],
       secrets: [
         "SECRET_TAG_1",
         "SECRET_TAG_2"
       ]
     }}
  end

  defp setup_proj_pfc_model(_context) do
    {:ok,
     proj_pfc_model: %Model.ProjectPFC{
       commands: [
         "checkout",
         "npm install",
         "npm run-script custom_security_check -- --some-option some-value"
       ],
       secrets: [
         "SECRET_TAG_3",
         "SECRET_TAG_4"
       ],
       has_custom_agent: true,
       agent: %Model.AgentConfig{
         machine_type: "a1-standard-4",
         os_image: "macos-xcode11"
       }
     }}
  end

  defp setup_organization_pfc(context) do
    organization_id = UUID.uuid4()

    Stubs.PreFlightChecks.create(
      :organization_pfc,
      organization_id,
      context[:org_pfc_params]
    )

    {:ok, organization_id: organization_id}
  end

  defp setup_project_pfc(context) do
    project_id = UUID.uuid4()

    Stubs.PreFlightChecks.create(
      :project_pfc,
      project_id,
      context[:proj_pfc_params]
    )

    {:ok, project_id: project_id}
  end
end
