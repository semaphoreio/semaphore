defmodule FeatureProvider.Cache do
  @type key :: any()
  @type value :: any()
  @type callback :: (() -> {:ok, value()} | {:error, any()})

  @type get_opts :: Keyword.t()
  @type set_opts :: Keyword.t()
  @type fetch_opts :: Keyword.t()

  @callback get(key(), get_opts()) :: value() | :not_found
  @callback set(key(), callback(), set_opts()) :: {:ok, value()} | {:error, any()}
  @callback fetch(key(), callback(), fetch_opts()) :: value() | :not_found
  @callback clear() :: :ok
  @callback unset(key()) :: :ok

  defmacro __using__(_opts) do
    quote do
      @behaviour FeatureProvider.Cache
    end
  end
end
