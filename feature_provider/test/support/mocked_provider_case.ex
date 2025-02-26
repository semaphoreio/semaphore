defmodule FeatureProvider.MockedProviderCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import FeatureProvider.MockedProviderCase

      import Mox
      setup :verify_on_exit!
    end
  end
end
