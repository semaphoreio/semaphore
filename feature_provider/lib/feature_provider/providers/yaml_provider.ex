defmodule FeatureProvider.YamlProvider do
  use FeatureProvider.Provider
  alias FeatureProvider.Feature

  @type yaml_feature :: {feature_name :: atom(), feature_setup :: map() | nil}

  @doc """
  Reads a features yaml file, parses it and starts an agent holding the features
  """
  def start_link(opts \\ []) do
    yaml_path =
      Keyword.get_lazy(opts, :yaml_path, fn ->
        raise(ArgumentError, "yaml_path must be a non-empty string")
      end)

    agent_name =
      Keyword.get_lazy(opts, :agent_name, fn ->
        raise(ArgumentError, "agent_name must be an atom")
      end)

    features =
      yaml_path
      |> features_from_file()

    Agent.start_link(fn -> features end, name: agent_name)
  end

  def child_spec(opts) do
    agent_name =
      Keyword.get_lazy(opts, :agent_name, fn ->
        raise(ArgumentError, "agent_name must be an atom")
      end)

    %{
      id: agent_name,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @doc """
  Fetches features from the running yaml agent
  """
  @impl FeatureProvider.Provider
  def provide_features(_param, opts \\ []) do
    agent_name = Keyword.get(opts, :agent_name)

    if is_nil(agent_name) do
      raise(ArgumentError, "agent_name must be an atom")
    end

    features = Agent.get(agent_name, & &1)

    {:ok, features}
  end

  @doc """
  Yaml provider does not provide information about machines
  """
  @impl FeatureProvider.Provider
  def provide_machines(_param, _opts \\ []) do
    {:ok, []}
  end

  @spec features_from_file(String.t()) :: [Feature.t()]
  defp features_from_file(feature_file_path) do
    feature_file_path
    |> YamlElixir.read_from_file!()
    |> Enum.map(&parse_yaml_feature/1)
  end

  @spec parse_yaml_feature(yaml_feature()) :: Feature.t()
  defp parse_yaml_feature({feature_key, feature_setup}) when not is_map(feature_setup),
    do: parse_yaml_feature({feature_key, %{}})

  defp parse_yaml_feature({feature_key, feature_setup}) do
    state = feature_state(feature_setup)
    quantity = feature_quantity(feature_setup, state)
    type = "#{feature_key}"
    name = feature_name(feature_setup, type)
    description = feature_description(feature_setup, name)

    %Feature{
      type: type,
      name: name,
      description: description,
      quantity: quantity,
      state: state
    }
  end

  @spec feature_state(map()) :: Feature.state()
  defp feature_state(feature_setup) do
    feature_setup["enabled"]
    |> case do
      nil -> :enabled
      true -> :enabled
      false -> :disabled
    end
  end

  @spec feature_quantity(map(), Feature.state()) :: Feature.quantity()
  defp feature_quantity(feature_setup, state) do
    feature_setup["quantity"]
    |> case do
      nil -> if(state == :enabled, do: 1, else: 0)
      quantity when is_bitstring(quantity) -> String.to_integer(quantity)
      quantity when is_number(quantity) -> quantity
    end
  end

  @spec feature_name(map(), String.t()) :: String.t()
  defp feature_name(feature_setup, type) do
    feature_setup["name"]
    |> case do
      nil -> type |> String.replace("_", " ") |> String.capitalize()
      name -> "#{name}"
    end
  end

  @spec feature_description(map(), String.t()) :: String.t()
  defp feature_description(feature_setup, name) do
    feature_setup["description"]
    |> case do
      nil -> name
      description -> "#{description}"
    end
  end
end
