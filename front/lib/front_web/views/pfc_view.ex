defmodule FrontWeb.PFCView do
  # agent environments

  def agent_envs(cloud_agents, self_hosted_agents, _org_id) do
    self_hosted_env = form_self_hosted_env(self_hosted_agents)
    cloud_envs = cloud_agents |> form_cloud_envs()

    if Enum.empty?(self_hosted_agents),
      do: cloud_envs,
      else: Map.put(cloud_envs, "SELF_HOSTED", self_hosted_env)
  end

  def agent_env(changeset, cloud_agents, self_hosted_agents, org_id) do
    agent_envs = agent_envs(cloud_agents, self_hosted_agents, org_id)
    Map.get(agent_envs, selected_env_type(changeset, agent_envs, org_id))
  end

  def selected_env_type(changeset, cloud_agents, self_hosted_agents, org_id) do
    selected_env_type(changeset, agent_envs(cloud_agents, self_hosted_agents, org_id), org_id)
  end

  defp selected_env_type(changeset, agent_envs, org_id) do
    machine_type =
      if is_nil(Ecto.Changeset.get_field(changeset, :machine_type)) do
        changeset
        |> Ecto.Changeset.get_field(:agent)
        |> Map.get(:machine_type)
      else
        Ecto.Changeset.get_field(changeset, :machine_type)
      end

    default_env = default_env(agent_envs, org_id)

    agent_envs
    |> Enum.find_value(default_env, fn {env_name, env} ->
      machine_types = Map.keys(env.machine_types)

      if Enum.member?(machine_types, machine_type),
        do: env_name,
        else: false
    end)
  end

  defp default_env(agent_envs, org_id) do
    if FeatureProvider.feature_enabled?(:expose_cloud_agent_types, param: org_id),
      do: Enum.find(["LINUX", "MAC"], &Map.has_key?(agent_envs, &1)),
      else: "SELF_HOSTED"
  end

  # forming agent environments

  defp form_self_hosted_env(agent_types) do
    map_agent = &{&1.name, %{type: &1.name, specs: "", os_images: []}}
    %{machine_types: Enum.into(agent_types, %{}, map_agent)}
  end

  defp form_cloud_envs(%{agent_types: []}), do: %{}

  defp form_cloud_envs(agent_types) do
    defaults = %{
      "LINUX" => agent_types.default_linux_os_image,
      "MAC" => agent_types.default_mac_os_image
    }

    agent_types.agent_types
    |> Enum.group_by(& &1.platform)
    |> Enum.into(%{}, &form_agent_env(defaults, &1))
  end

  defp form_agent_env(default_images, {platform, agent_types}) do
    machine_types =
      agent_types
      |> Enum.group_by(& &1.type)
      |> Enum.into(%{}, &form_machine_type/1)

    {platform,
     %{
       machine_types: machine_types,
       default_os_image: default_images[platform]
     }}
  end

  defp form_machine_type({machine_type, agent_types}) do
    {machine_type,
     %{
       specs: agent_types |> List.first() |> Map.get(:specs, machine_type),
       os_images: Enum.into(agent_types, [], & &1.os_image),
       type: machine_type
     }}
  end

  # rendering options

  def secret_options(changeset, secrets) do
    available_secrets = MapSet.new(secrets, & &1.name)
    selected_secrets = changeset |> Ecto.Changeset.get_field(:secrets, []) |> MapSet.new()
    stale_secrets = MapSet.difference(selected_secrets, available_secrets)

    fresh_options = Enum.into(available_secrets, [], &to_fresh_option/1)
    stale_options = Enum.into(stale_secrets, [], &to_stale_option/1)
    fresh_options ++ stale_options
  end

  def env_type_options(cloud_agents, self_hosted_agents, org_id) do
    values = Map.keys(agent_envs(cloud_agents, self_hosted_agents, org_id))
    Enum.map(values, &to_fresh_option(env_type_key(&1), &1))
  end

  defp env_type_key("LINUX"), do: "Linux Based Virtual Machine"
  defp env_type_key("MAC"), do: "Mac Based Virtual Machine"
  defp env_type_key("SELF_HOSTED"), do: "Self Hosted Machine"

  def machine_type_options(changeset, cloud_agents, self_hosted_agents, org_id) do
    agent_envs = agent_envs(cloud_agents, self_hosted_agents, org_id)
    env_type = selected_env_type(changeset, agent_envs, org_id)
    to_option = &to_fresh_option(gen_labeler(env_type).(&1), &1.type)

    agent_envs
    |> Map.get(env_type, %{})
    |> Map.get(:machine_types, %{})
    |> Map.values()
    |> Enum.into([], to_option)
  end

  defp gen_labeler("SELF_HOSTED"), do: &"#{&1.type}"
  defp gen_labeler(_cloud_env), do: &"#{&1.type} (#{&1.specs})"

  def os_image_options(changeset, cloud_agents, self_hosted_agents, org_id) do
    agent_env = agent_env(changeset, cloud_agents, self_hosted_agents, org_id)
    default_os_image = agent_env[:default_os_image]

    machine_type =
      if is_nil(Ecto.Changeset.get_field(changeset, :machine_type)) do
        changeset
        |> Ecto.Changeset.get_field(:agent)
        |> Map.get(:machine_type)
      else
        Ecto.Changeset.get_field(changeset, :machine_type)
      end

    os_images =
      if machine_type && String.length(machine_type) > 1 &&
           Map.has_key?(agent_env.machine_types, machine_type),
         do: agent_env.machine_types[machine_type][:os_images],
         else: agent_env.machine_types |> Map.values() |> List.first() |> Map.get(:os_images)

    os_images =
      if default_os_image && Enum.member?(os_images, default_os_image),
        do: Enum.uniq([default_os_image | os_images]),
        else: os_images

    Enum.into(os_images, [], &to_fresh_option/1)
  end

  defp to_fresh_option(value), do: to_fresh_option(value, value)
  defp to_fresh_option(key, value), do: [key: key, value: value]

  defp to_stale_option(value), do: to_stale_option(value, value)
  defp to_stale_option(key, value), do: [key: key, value: value, disabled: true]
end
