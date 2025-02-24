defmodule FeatureProvider.Provider do
  @type param :: any()
  @typedoc """
  - `:provider_opts` - Keyword list of options passed from the provider.
  """
  @type opts :: [provider_opts: Keyword.t()] | Keyword.t()

  @doc """
  Provides a list of features for a given `param`.

  `param` can be used to add a parameter to the provider. See `ParametrizedProvider` for an example.
  """

  @callback provide_features(param(), opts()) :: {:ok, [FeatureProvider.Feature.t()]} | {:error, any()}
  @callback provide_machines(param(), opts()) :: {:ok, [FeatureProvider.Machine.t()]} | {:error, any()}

  defmacro __using__(_opts) do
    quote do
      @behaviour FeatureProvider.Provider
    end
  end
end
