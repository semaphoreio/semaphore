defmodule FeatureProvider do
  alias FeatureProvider.{
    Feature,
    Machine,
    Util
  }

  @type feature_type :: String.t() | atom()
  @type machine_type :: String.t() | atom()
  @type provider :: atom() | {atom(), Keyword.t()}
  @type cache :: atom() | {atom(), Keyword.t()}

  @typedoc """
  - `:cache` - A cache module that will be used to cache the results of the provider. Refer to `FeatureProvider.Cache` for more information.
  """
  @type opts ::
          Keyword.t()
          | [
              cache: cache()
            ]

  import Util

  @doc since: "0.2.0"
  @doc """
  Puts the provider configuration in the application environment.
  """
  @spec init(provider()) :: :ok
  def init(provider) do
    Application.put_env(FeatureProvider, :provider, provider_with_opts!(provider))
  end

  @doc since: "0.2.0"
  @doc """
  Finds a feature given its `feature_type`.

  ## Examples

      iex> {:ok, feature} = find_feature("enabled_feature")
      ...> feature.type
      "enabled_feature"

      iex> {:ok, feature} = find_feature(:enabled_feature)
      ...> feature.type
      "enabled_feature"

      iex> {:ok, feature} = find_feature(:hidden_feature)
      ...> feature.type
      "hidden_feature"

      iex> {:ok, feature} = find_feature(:zero_state_feature)
      ...> feature.type
      "zero_state_feature"
  """
  @spec find_feature(feature_type(), opts()) :: Util.maybe([Feature.t()])
  def find_feature(feature_type, opts \\ []) do
    list_features(opts)
    |> unwrap(fn features ->
      Enum.find(features, &(&1.type == "#{feature_type}"))
      |> case do
        nil -> {:error, {:not_found, feature_type}}
        feature -> {:ok, feature}
      end
    end)
  end

  @doc since: "0.2.0"
  @doc """
  Checks if a `feature_type` is enabled.

  ## Examples

      iex> feature_enabled?("enabled_feature")
      true

      iex> feature_enabled?(:disabled_feature)
      false

      iex> feature_enabled?(:zero_state_feature)
      false

      iex> feature_enabled?(:non_existent_feature)
      false
  """
  @spec feature_enabled?(feature_type(), opts()) :: boolean()
  def feature_enabled?(feature_type, opts \\ []) do
    find_feature(feature_type, opts)
    |> case do
      {:ok, feature} -> Feature.enabled?(feature)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Checks if a `feature_type` is in a zero state.

  ## Examples

      iex> feature_zero_state?("enabled_feature")
      false

      iex> feature_zero_state?(:disabled_feature)
      false

      iex> feature_zero_state?(:zero_state_feature)
      true

      iex> feature_zero_state?(:non_existent_feature)
      false
  """
  @spec feature_zero_state?(feature_type(), opts()) :: boolean()
  def feature_zero_state?(feature_type, opts \\ []) do
    find_feature(feature_type, opts)
    |> case do
      {:ok, feature} -> Feature.zero_state?(feature)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Checks if a `feature_type` is in visible.

  ## Examples

      iex> feature_visible?("enabled_feature")
      true

      iex> feature_visible?(:disabled_feature)
      false

      iex> feature_visible?(:zero_state_feature)
      true

      iex> feature_visible?(:non_existent_feature)
      false
  """
  @spec feature_visible?(feature_type(), opts()) :: boolean()
  def feature_visible?(feature_type, opts \\ []) do
    find_feature(feature_type, opts)
    |> case do
      {:ok, feature} -> Feature.visible?(feature)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Returns a quantity on the `feature_type`.

  ## Examples

      iex> feature_quota("enabled_feature")
      1

      iex> feature_quota(:disabled_feature)
      0

      iex> feature_quota(:zero_state_feature)
      50

      iex> feature_quota(:non_existent_feature)
      0
  """
  @doc since: "0.2.0"
  @spec feature_quota(feature_type(), opts()) :: Feature.quantity()
  def feature_quota(feature_type, opts \\ []) do
    find_feature(feature_type, opts)
    |> case do
      {:ok, feature} -> Feature.quota(feature)
      _ -> 0
    end
  end

  @doc since: "0.2.0"
  @doc """
  Lists all features for the given `provider`.

  ## Examples

    iex> {:ok, features} = list_features()
    ...> length(features)
    3
  """
  @spec list_features(opts()) :: Util.maybe(Feature.t())
  def list_features(opts \\ []) do
    maybe_cached_load(:provide_features, opts)
  rescue
    e ->
      log_fun(exception: Exception.format(:error, e, __STACKTRACE__), opts: opts)
      {:error, {:provider_exception, e}}
  end

  @doc since: "0.2.0"
  @doc """
  Finds a machine given its `machine_type`.

  ## Examples

      iex> {:ok, machine} = find_machine("t1-test-2")
      ...> machine.type
      "t1-test-2"

      iex> {:ok, machine} = find_machine("t1-test-4")
      ...> machine.type
      "t1-test-4"

      iex> {:ok, machine} = find_machine("tx1-test-2")
      ...> machine.type
      "tx1-test-2"

      iex> {:ok, machine} = find_machine("ax1-test-2")
      ...> machine.type
      "ax1-test-2"

      iex> {:error, {:not_found, _}} = find_machine("tx1-test-4")
  """
  @spec find_machine(machine_type(), opts()) :: Util.maybe([Machine.t()])
  def find_machine(machine_type, opts \\ []) do
    list_machines(opts)
    |> unwrap(fn machines ->
      Enum.find(machines, &(&1.type == "#{machine_type}"))
      |> case do
        nil -> {:error, {:not_found, machine_type}}
        machine -> {:ok, machine}
      end
    end)
  end

  @doc since: "0.2.0"
  @doc """
  Checks if a `machine_type` is enabled.

  ## Examples

      iex> machine_enabled?("t1-test-2")
      true

      iex> machine_enabled?("t1-test-4")
      true

      iex> machine_enabled?("tx1-test-2")
      false

      iex> machine_enabled?("ax1-test-2")
      false

      iex> machine_enabled?("tx1-test-4")
      false
  """
  @spec machine_enabled?(machine_type(), opts()) :: boolean()
  def machine_enabled?(machine_type, opts \\ []) do
    find_machine(machine_type, opts)
    |> case do
      {:ok, machine} -> Machine.enabled?(machine)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Checks if a `machine_type` is in a zero state.

  ## Examples

      iex> machine_zero_state?("t1-test-2")
      false

      iex> machine_zero_state?("t1-test-4")
      false

      iex> machine_zero_state?("tx1-test-2")
      true

      iex> machine_zero_state?("ax1-test-2")
      false

      iex> machine_zero_state?("tx1-test-4")
      false
  """
  @spec machine_zero_state?(machine_type(), opts()) :: boolean()
  def machine_zero_state?(machine_type, opts \\ []) do
    find_machine(machine_type, opts)
    |> case do
      {:ok, machine} -> Machine.zero_state?(machine)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Checks if a `machine_type` is visible.

  ## Examples

      iex> machine_visible?("t1-test-2")
      true

      iex> machine_visible?("t1-test-4")
      true

      iex> machine_visible?("tx1-test-2")
      true

      iex> machine_visible?("ax1-test-2")
      false

      iex> machine_visible?("tx1-test-4")
      false
  """
  @spec machine_visible?(machine_type(), opts()) :: boolean()
  def machine_visible?(machine_type, opts \\ []) do
    find_machine(machine_type, opts)
    |> case do
      {:ok, machine} -> Machine.visible?(machine)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Returns a quota on the `machine_type`.

  ## Examples

      iex> machine_quota("t1-test-2")
      10

      iex> machine_quota("t1-test-4")
      5

      iex> machine_quota("tx1-test-2")
      1

      iex> machine_quota("ax1-test-2")
      0

      iex> machine_quota("tx1-test-4")
      0
  """
  @doc since: "0.2.0"
  @spec machine_quota(machine_type(), opts()) :: Machine.quantity()
  def machine_quota(machine_type, opts \\ []) do
    find_machine(machine_type, opts)
    |> case do
      {:ok, machine} -> Machine.quota(machine)
      _ -> 0
    end
  end

  @doc since: "0.2.0"
  @doc """
  Checks if `machine_type` is a macos type machine.

  ## Examples

      iex> machine_mac?("t1-test-2")
      false

      iex> machine_mac?("t1-test-4")
      false

      iex> machine_mac?("tx1-test-2")
      false

      iex> machine_mac?("ax1-test-2")
      true

      iex> machine_mac?("tx1-test-4")
      false
  """
  @doc since: "0.2.0"
  @spec machine_mac?(machine_type(), opts()) :: boolean()
  def machine_mac?(machine_type, opts \\ []) do
    find_machine(machine_type, opts)
    |> case do
      {:ok, machine} -> Machine.mac?(machine)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Checks if `machine_type` is a linux type machine.

  ## Examples

      iex> machine_linux?("t1-test-2")
      true

      iex> machine_linux?("t1-test-4")
      true

      iex> machine_linux?("tx1-test-2")
      true

      iex> machine_linux?("ax1-test-2")
      false

      iex> machine_linux?("tx1-test-4")
      false
  """
  @doc since: "0.2.0"
  @spec machine_linux?(machine_type(), opts()) :: boolean()
  def machine_linux?(machine_type, opts \\ []) do
    find_machine(machine_type, opts)
    |> case do
      {:ok, machine} -> Machine.linux?(machine)
      _ -> false
    end
  end

  @doc since: "0.2.0"
  @doc """
  Lists all machines for the given `provider`.

  ## Examples

      iex> {:ok, machines} = list_machines()
      ...> length(machines)
      4
  """
  @spec list_machines(opts()) :: Util.maybe(Machine.t())
  def list_machines(opts \\ []) do
    maybe_cached_load(:provide_machines, opts)
  rescue
    e ->
      log_fun(exception: Exception.format(:error, e, __STACKTRACE__), opts: opts)
      {:error, {:provider_exception, e}}
  end

  @spec maybe_cached_load(atom(), opts()) :: Util.maybe([Feature.t()] | [Machine.t()])
  defp maybe_cached_load(fun_name, opts) do
    {param, opts} = Keyword.pop(opts, :param)

    provider =
      Keyword.get_lazy(opts, :provider, fn ->
        Application.fetch_env!(FeatureProvider, :provider)
      end)

    {provider, provider_opts} = provider_with_opts!(provider)
    provider_opts = Keyword.merge(provider_opts, opts)
    {cache, cache_opts} = cache_with_opts(provider_opts)
    loader = fn -> apply(provider, fun_name, [param, provider_opts]) end

    if cache do
      {fun_name, param}
      |> cache.fetch(loader, cache_opts)
      |> case do
        :not_found -> {:error, {:not_found, {fun_name, param}}}
        other -> {:ok, other}
      end
    else
      loader.()
    end
  end

  @spec provider_with_opts!(any()) :: provider()
  defp provider_with_opts!(provider) do
    provider
    |> case do
      {provider, provider_opts} when is_atom(provider) and is_list(provider_opts) ->
        {provider, provider_opts}

      provider when is_atom(provider) ->
        {provider, []}

      other ->
        raise ArgumentError,
              "provider must be an atom or a tuple of {atom, keyword}, got: #{inspect(other)}"
    end
  end

  @spec cache_with_opts(opts :: Keyword.t()) :: {atom(), Keyword.t()}
  defp cache_with_opts(opts) do
    reload? = Keyword.get(opts, :reload, false)
    invalidate? = Keyword.get(opts, :invalidate, false)

    Keyword.get(opts, :cache)
    |> case do
      {cache, cache_opts} when is_atom(cache) and is_list(cache_opts) -> {cache, cache_opts}
      cache when is_atom(cache) -> {cache, []}
      _other -> {nil, []}
    end
    |> case do
      {nil, []} ->
        {nil, []}

      {cache, cache_opts} ->
        opts = Keyword.merge(cache_opts, reload: reload?, invalidate: invalidate?)
        {cache, opts}
    end
  end
end
