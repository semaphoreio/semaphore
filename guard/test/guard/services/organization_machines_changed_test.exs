defmodule Guard.Services.OrganizationMachinesChanged.Test do
  use Guard.RepoCase
  import Mock

  alias Guard.FrontRepo
  alias FrontRepo.Organization

  describe ".handle_message" do
    test "overwrites plan defaults when organization settings are not null" do
      assert {:ok, organization} =
               %Organization{}
               |> Ecto.Changeset.cast(
                 %{
                   name: "rtx",
                   settings: %{
                     "plan_machine_type" => "e1-standard-2",
                     "plan_os_image" => "ubuntu1804",
                     "custom_machine_type" => "e1-standard-4",
                     "custom_os_image" => "ubuntu2004"
                   }
                 },
                 [:name, :settings]
               )
               |> FrontRepo.insert()

      with_mock Guard.FeatureHubProvider,
        provide_default_machine: fn _, _ ->
          {:ok,
           %FeatureProvider.Machine{
             type: "e2-standard-2",
             default_os_image: "ubuntu2204"
           }}
        end do
        event = InternalApi.Feature.OrganizationMachinesChanged.new(org_id: organization.id)
        message = InternalApi.Feature.OrganizationMachinesChanged.encode(event)
        Guard.Services.OrganizationMachinesChanged.handle_message(message)
      end

      assert organization = FrontRepo.get(Organization, organization.id)

      assert organization.settings == %{
               "plan_machine_type" => "e2-standard-2",
               "plan_os_image" => "ubuntu2204",
               "custom_machine_type" => "e1-standard-4",
               "custom_os_image" => "ubuntu2004"
             }
    end

    test "sets settings with plan defaults when settings are null" do
      assert {:ok, organization} =
               %Organization{}
               |> Ecto.Changeset.cast(%{name: "rtx"}, [:name])
               |> FrontRepo.insert()

      with_mock Guard.FeatureHubProvider,
        provide_default_machine: fn _, _ ->
          {:ok,
           %FeatureProvider.Machine{
             type: "e2-standard-2",
             default_os_image: "ubuntu2204"
           }}
        end do
        event = InternalApi.Feature.OrganizationMachinesChanged.new(org_id: organization.id)
        message = InternalApi.Feature.OrganizationMachinesChanged.encode(event)
        Guard.Services.OrganizationMachinesChanged.handle_message(message)
      end

      assert organization = FrontRepo.get(Organization, organization.id)

      assert organization.settings == %{
               "plan_machine_type" => "e2-standard-2",
               "plan_os_image" => "ubuntu2204"
             }
    end
  end
end
