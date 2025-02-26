defmodule Front.TestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Support.FakeServices, as: FS
    end
  end

  setup tags do
    FunRegistry.start()
    FunRegistry.clear!()
    Support.FakeServices.stub_responses()
    Cachex.clear(:front_cache)
    Cachex.clear(:auth_cache)
    Cachex.clear!(:feature_provider_cache)
    Cacheman.clear(:front)
    Support.Stubs.init()

    tags
  end
end
