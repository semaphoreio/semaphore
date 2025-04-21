defmodule Support.Stubs.Feature do
  alias InternalApi.Feature, as: API
  alias Support.Stubs.DB

  @type availability_option :: {:state, :ENABLED | :HIDDEN | :ZERO_STATE} | {:quantity, integer}
  @type platform_option ::
          {:platform, :linux | :mac}
          | {:os_images, [String.t()]}
          | {:default_os_image, String.t()}
  @type spec_option :: {:vcpu, String.t()} | {:ram, String.t()} | {:disk, String.t()}

  @type feature_option :: availability_option | {:name, String.t()} | {:description, String.t()}
  @type machine_option :: availability_option | platform_option | spec_option
  @type row(t) :: %{id: any(), model: t}

  def init do
    DB.add_table(:machines, [:id, :model])
    DB.add_table(:features, [:id, :model])
    DB.add_table(:organization_machines, [:id, :model])
    DB.add_table(:organization_features, [:id, :model])

    seed()
  end

  def seed do
    if System.get_env("SEED_CE_FEATURES") == "true" do
      seed_ce_features()
    else
      seed_ee_features()
    end

    if System.get_env("SEED_CLOUD_MACHINES") == "true" do
      seed_machines()
    end
  end

  @spec seed_ce_features :: [row(API.Feature.t())]
  def seed_ce_features do
    (ce_features() ++ common_features())
    |> Enum.map(fn {feature_type, feature_opts} ->
      setup_feature(feature_type, feature_opts)
    end)
  end

  @spec seed_ee_features :: [row(API.Feature.t())]
  def seed_ee_features do
    (ee_features() ++ common_features())
    |> Enum.map(fn {feature_type, feature_opts} ->
      setup_feature(feature_type, feature_opts)
    end)
  end

  defp ee_features, do: []

  defp ce_features, do: []

  defp common_features,
    do: [
      {"experimental_canvas_ui", state: :ENABLED, quantity: 1},
      {"rbac__saml", state: :ENABLED, quantity: 1}
    ]

  @doc """
  Creates or updates a feature
  """
  @spec setup_feature(feature_type :: String.t(), [feature_option]) :: row(API.Feature.t())
  def setup_feature(feature_type, opts \\ []) do
    feature_type = "#{feature_type}"
    name = opts[:name] || feature_type |> String.replace("_", " ") |> String.capitalize()
    description = opts[:description] || "Description of #{name} feature"
    availability = availability_from_opts(opts)

    feature =
      API.Feature.new(%{
        type: feature_type,
        name: name,
        description: description,
        availability: availability
      })

    DB.upsert(:features, %{
      id: feature_type,
      model: feature
    })
  end

  def enable_feature(org_id, feature_type),
    do: set_org_feature(org_id, feature_type, state: :ENABLED, quantity: 1)

  def disable_feature(org_id, feature_type),
    do: set_org_feature(org_id, feature_type, state: :HIDDEN, quantity: 0)

  def zero_feature(org_id, feature_type),
    do: set_org_feature(org_id, feature_type, state: :ZERO_STATE, quantity: 1)

  @doc """
  Creates or updates a machine
  """
  @spec setup_machine(machine_type :: String.t(), [machine_option]) :: row(API.Machine.t())
  def setup_machine(machine_type, opts \\ []) do
    machine_type = "#{machine_type}"
    availability = availability_from_opts(opts)
    {platform, os_images, os_default_image} = platform_from_opts(opts)
    {vcpu, ram, disk} = specs_from_opts(opts)

    machine =
      API.Machine.new(%{
        type: machine_type,
        availability: availability,
        platform: platform,
        os_images: os_images,
        default_os_image: os_default_image,
        vcpu: vcpu,
        ram: ram,
        disk: disk
      })

    DB.upsert(:machines, %{
      id: machine_type,
      model: machine
    })
  end

  def enable_machine(org_id, machine_type, quota \\ 1),
    do: set_org_machine(org_id, machine_type, state: :ENABLED, quantity: quota)

  def disable_machine(org_id, machine_type),
    do: set_org_machine(org_id, machine_type, state: :HIDDEN)

  @spec reset_org_machines(org_id :: String.t(), Keyword.t()) :: :ok
  def reset_org_machines(org_id, _opts \\ []) do
    DB.delete(:organization_machines, fn row ->
      match?({^org_id, _}, row.id)
    end)

    :ok
  end

  @doc """
  Sets organization's machine/feature setup based on available machines/features.
  """
  @spec set_org_defaults(org_id :: String.t()) ::
          {[row(API.OrganizationMachine.t())], [row(API.OrganizationFeature.t())]}
  def set_org_defaults(org_id) do
    DB.delete(:organization_machines, fn
      %{id: {^org_id, _}} -> true
      _ -> false
    end)

    DB.delete(:organization_features, fn
      %{id: {^org_id, _}} -> true
      _ -> false
    end)

    machines =
      DB.all(:machines)
      |> Enum.map(& &1.model.type)
      |> Enum.map(fn machine_type ->
        set_org_machine(org_id, machine_type)
      end)

    features =
      DB.all(:features)
      |> Enum.map(& &1.model.type)
      |> Enum.map(fn feature_type ->
        set_org_feature(org_id, feature_type)
      end)

    {machines, features}
  end

  @spec set_org_feature(org_id :: String.t(), feature_type :: String.t(), [availability_option]) ::
          row(API.OrganizationFeature.t())
  defp set_org_feature(org_id, feature_type, opts \\ []) do
    feature_type = "#{feature_type}"

    feature =
      DB.find_by(:features, :id, feature_type)
      |> case do
        nil ->
          raise "Feature #{feature_type} not found"

        %{model: feature} ->
          feature
      end

    availability = availability_from_opts(opts, feature.availability)

    organization_feature =
      API.OrganizationFeature.new(%{
        org_id: org_id,
        feature: feature,
        availability: availability
      })

    DB.upsert(:organization_features, %{
      id: {org_id, feature_type},
      model: organization_feature
    })
  end

  @spec set_org_machine(org_id :: String.t(), machine_type :: String.t(), [availability_option]) ::
          row(API.OrganizationMachine.t())
  defp set_org_machine(org_id, machine_type, opts \\ []) do
    machine_type = "#{machine_type}"

    machine =
      DB.find_by(:machines, :id, machine_type)
      |> case do
        nil ->
          raise "Machine #{machine_type} not found"

        %{model: machine} ->
          machine
      end

    availability = availability_from_opts(opts, machine.availability)

    organization_machine =
      API.OrganizationMachine.new(%{
        machine: machine,
        availability: availability
      })

    DB.upsert(:organization_machines, %{
      id: {org_id, machine_type},
      model: organization_machine
    })
  end

  @spec platform_from_opts(opts :: [platform_option]) ::
          {platform :: API.Machine.Platform.t(), os_images :: [String.t()],
           os_default_image :: String.t()}
  defp platform_from_opts(opts) do
    defaults = [
      linux: ["ubuntu2004", "ubuntu1804"],
      mac: ["xcode13", "xcode12"]
    ]

    with platform <- opts[:platform] || :linux || :LINUX,
         os_images <- opts[:os_images] || defaults[platform],
         default_image <- opts[:os_default_image] || hd(os_images),
         platform <- "#{platform}" |> String.upcase() |> String.to_existing_atom() do
      {API.Machine.Platform.value(platform), os_images, default_image}
    end
  end

  @spec specs_from_opts(opts :: [spec_option]) ::
          {vcpu :: String.t(), ram :: String.t(), disk :: String.t()}
  defp specs_from_opts(opts) do
    with vcpu <- opts[:vcpu] || "1",
         ram <- opts[:ram] || "2",
         disk <- opts[:disk] || "10" do
      {vcpu, ram, disk}
    end
  end

  @spec availability_from_opts([availability_option]) :: Map.t()
  # credo:disable-for-next-line
  defp availability_from_opts(opts, default_availability \\ nil) do
    availability =
      default_availability
      |> case do
        nil -> %API.Availability{}
        %API.Availability{} -> default_availability
      end

    availability =
      opts[:quantity]
      |> case do
        nil ->
          availability

        quantity ->
          %{availability | quantity: quantity}
      end

    opts[:state]
    |> case do
      nil ->
        availability

      :ENABLED ->
        %{availability | state: API.Availability.State.value(:ENABLED)}

      :HIDDEN ->
        %{availability | state: API.Availability.State.value(:HIDDEN)}

      :ZERO_STATE ->
        %{availability | state: API.Availability.State.value(:ZERO_STATE)}

      state ->
        raise "Unknown state: #{state}"
    end
  end

  @spec seed_machines :: [row(API.Machine.t())]
  def seed_machines do
    mac_images = ["macos-xcode13", "macos-xcode12"]

    [
      {"g1-standard-2", platform: :linux, vcpu: "2", ram: "??", disk: "??", state: :HIDDEN},
      {"g1-standard-4", platform: :linux, vcpu: "4", ram: "??", disk: "??", state: :HIDDEN},
      {"e1-standard-2",
       platform: :linux, vcpu: "2", ram: "4", disk: "25", state: :ENABLED, quantity: 8},
      {"e1-standard-4",
       platform: :linux, vcpu: "4", ram: "8", disk: "35", state: :ENABLED, quantity: 8},
      {"e1-standard-8",
       platform: :linux, vcpu: "8", ram: "16", disk: "45", state: :ENABLED, quantity: 2},
      {"f1-standard-2", platform: :linux, vcpu: "2", ram: "8", disk: "55", state: :ZERO_STATE},
      {"f1-standard-4", platform: :linux, vcpu: "4", ram: "16", disk: "75", state: :ZERO_STATE},
      {"f1-standard-8", platform: :linux, vcpu: "8", ram: "32", disk: "100", state: :ZERO_STATE},
      {"a1-standard-4",
       platform: :mac,
       vcpu: "4",
       ram: "8",
       disk: "50",
       state: :ENABLED,
       os_images: mac_images,
       quantity: 2},
      {"a1-standard-8",
       platform: :mac,
       vcpu: "8",
       ram: "16",
       disk: "50",
       state: :ENABLED,
       os_images: mac_images,
       quantity: 2}
    ]
    |> Enum.map(fn {machine_type, machine_opts} ->
      setup_machine(machine_type, machine_opts)
    end)
  end

  defmodule Grpc do
    use GRPC.Server, service: InternalApi.Feature.FeatureService.Service

    def list_organization_features(request, _) do
      org_id = request.org_id

      DB.filter(:organization_features, fn
        %{id: {^org_id, _}} -> true
        _ -> false
      end)
      |> Enum.map(& &1.model)
      |> then(&API.ListOrganizationFeaturesResponse.new(organization_features: &1))
    end

    def list_organization_machines(request, _) do
      org_id = request.org_id

      DB.filter(:organization_machines, fn
        %{id: {^org_id, _}} -> true
        _ -> false
      end)
      |> Enum.map(& &1.model)
      |> then(&API.ListOrganizationMachinesResponse.new(organization_machines: &1))
    end

    def list_machines(_request, _) do
      DB.all(:machines)
      |> Enum.map(& &1.model)
      |> then(&API.ListMachinesResponse.new(machines: &1))
    end

    def list_features(_request, _) do
      DB.all(:features)
      |> Enum.map(& &1.model)
      |> then(&API.ListFeaturesResponse.new(features: &1))
    end
  end
end
