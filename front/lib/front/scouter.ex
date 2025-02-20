defmodule Front.Scouter do
  defmodule Behaviour do
    @type context :: %{
            org_id: String.t(),
            project_id: String.t(),
            user_id: String.t()
          }
    @type event :: %{
            id: String.t(),
            occured_at: DateTime.t()
          }

    @callback signal(context :: context(), event_id :: String.t()) ::
                {:ok, event()} | {:error, any}
    @callback list(context :: context(), event_ids :: [String.t()]) ::
                {:ok, [event()]} | {:error, any}
  end

  {client, _client_opts} = Application.compile_env!(:front, :scouter_client)

  @behaviour Behaviour

  @impl Behaviour
  defdelegate signal(context, event_id), to: client

  @impl Behaviour
  defdelegate list(context, event_ids), to: client
end
