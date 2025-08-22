defmodule Support.FakeClients.ServiceAccount do
  @moduledoc """
  Fake implementation of the ServiceAccount client for testing purposes.
  This module uses an Agent to store service accounts in memory.
  It simulates the behaviour of the actual ServiceAccount client.
  It provides methods to create, list, describe, update, delete, and regenerate tokens for service accounts.
  This is useful for testing and development without needing a real backend.
  """
  use Agent
  @behaviour Front.ServiceAccount.Behaviour

  alias InternalApi.ServiceAccount.ServiceAccount
  alias Support.Stubs.RBAC

  @doc """
  Starts the fake service account agent with empty state
  """
  def start_link(opts \\ []) do
    Agent.start_link(
      fn -> %{service_accounts: %{}, tokens: %{}} end,
      Keyword.put_new(opts, :name, __MODULE__)
    )
  end

  @doc """
  Resets the agent state - useful for tests
  """
  def reset do
    Agent.update(__MODULE__, fn _ -> %{service_accounts: %{}, tokens: %{}} end)
  end

  @impl Front.ServiceAccount.Behaviour
  def create(org_id, name, description, creator_id) do
    cond do
      name == "" ->
        {:error, "Service account name cannot be empty"}

      String.length(name) > 100 ->
        {:error, "Service account name is too long (maximum 100 characters)"}

      true ->
        service_account = %ServiceAccount{
          id: Ecto.UUID.generate(),
          name: name,
          description: description,
          org_id: org_id,
          creator_id: creator_id,
          created_at: now_proto_timestamp(),
          updated_at: now_proto_timestamp(),
          deactivated: false
        }

        api_token = generate_token()

        Agent.update(__MODULE__, fn state ->
          RBAC.add_service_account(org_id, service_account)

          state
          |> put_in([:service_accounts, service_account.id], service_account)
          |> put_in([:tokens, service_account.id], api_token)
        end)

        {:ok, {service_account, api_token}}
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def describe_many(service_account_ids) do
    service_accounts =
      service_account_ids
      |> Enum.map(fn id ->
        describe(id)
      end)
      |> Enum.filter(fn
        {:ok, _} -> true
        _ -> false
      end)
      |> Enum.map(fn {:ok, account} -> account end)

    {:ok, service_accounts}
  end

  @impl Front.ServiceAccount.Behaviour
  def list(org_id, page_size, page_token) do
    cond do
      page_size < 1 ->
        {:error, "Page size must be greater than 0"}

      page_size > 1000 ->
        {:error, "Page size too large (maximum 1000)"}

      true ->
        service_accounts =
          Agent.get(__MODULE__, fn state ->
            state.service_accounts
            |> Map.values()
            |> Enum.filter(&(&1.org_id == org_id))
            |> Enum.sort_by(& &1.created_at, {:desc, DateTime})
          end)

        # Simple pagination implementation
        {page_accounts, has_more} = paginate_results(service_accounts, page_size, page_token)
        next_page_token = if has_more, do: generate_page_token(page_accounts), else: nil

        {:ok, {page_accounts, next_page_token}}
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def describe(service_account_id) do
    case Agent.get(__MODULE__, &get_in(&1, [:service_accounts, service_account_id])) do
      nil -> {:error, "Service account not found"}
      service_account -> {:ok, service_account}
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def update(service_account_id, name, description) do
    cond do
      name == "" ->
        {:error, "Service account name cannot be empty"}

      String.length(name) > 100 ->
        {:error, "Service account name is too long (maximum 100 characters)"}

      !valid_uuid?(service_account_id) ->
        {:error, "Invalid service account ID format"}

      true ->
        Agent.get_and_update(__MODULE__, fn state ->
          case get_in(state, [:service_accounts, service_account_id]) do
            nil ->
              {{:error, "Service account not found"}, state}

            service_account ->
              updated_account = %{
                service_account
                | name: name,
                  description: description,
                  updated_at: now_proto_timestamp()
              }

              new_state = put_in(state, [:service_accounts, service_account_id], updated_account)

              {{:ok, updated_account}, new_state}
          end
        end)
    end
  end

  @impl Front.ServiceAccount.Behaviour
  def delete(service_account_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case get_in(state, [:service_accounts, service_account_id]) do
        nil ->
          {{:error, "Service account not found"}, state}

        _service_account ->
          new_state =
            state
            |> update_in([:service_accounts], &Map.delete(&1, service_account_id))
            |> update_in([:tokens], &Map.delete(&1, service_account_id))

          {:ok, new_state}
      end
    end)
  end

  @impl Front.ServiceAccount.Behaviour
  def regenerate_token(service_account_id) do
    Agent.get_and_update(__MODULE__, fn state ->
      case get_in(state, [:service_accounts, service_account_id]) do
        nil ->
          {{:error, "Service account not found"}, state}

        _service_account ->
          new_token = generate_token()
          new_state = put_in(state, [:tokens, service_account_id], new_token)
          {{:ok, new_token}, new_state}
      end
    end)
  end

  defp generate_token do
    "sa_" <> Base.encode64(:crypto.strong_rand_bytes(32), padding: false)
  end

  defp valid_uuid?(string) do
    case Ecto.UUID.cast(string) do
      {:ok, _} -> true
      :error -> false
    end
  end

  defp paginate_results(items, page_size, nil) do
    {Enum.take(items, page_size), length(items) > page_size}
  end

  defp paginate_results(items, page_size, page_token) do
    start_index =
      case Enum.find_index(items, &(&1.id == page_token)) do
        nil -> 0
        index -> index + 1
      end

    remaining = Enum.drop(items, start_index)
    {Enum.take(remaining, page_size), length(remaining) > page_size}
  end

  defp generate_page_token([]), do: nil
  defp generate_page_token(accounts), do: List.last(accounts).id

  defp now_proto_timestamp do
    seconds = DateTime.utc_now() |> DateTime.to_unix()
    Google.Protobuf.Timestamp.new(seconds: seconds)
  end
end
