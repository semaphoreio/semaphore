defmodule Front.Superjerry do
  defmodule Behaviour do
    @callback list_flaky_tests(
                org_id :: String.t(),
                project_id :: String.t(),
                page :: Integer.t(),
                page_size :: Integer.t(),
                sort_field :: String.t(),
                sort_dir :: String.t(),
                filters :: any
              ) :: {:ok, {[Front.Models.TestExplorer.FlakyTestItem.t()], any()}} | {:error, any}

    @callback list_disruption_history(
                org_id :: String.t(),
                project_id :: String.t(),
                filters :: any
              ) :: {:ok, [Front.Models.TestExplorer.HistoryItem.t()]} | {:error, any}

    @callback list_flaky_history(
                org_id :: String.t(),
                project_id :: String.t(),
                filters :: any
              ) :: {:ok, [Front.Models.TestExplorer.HistoryItem.t()]} | {:error, any}

    @callback flaky_test_details(
                org_id :: String.t(),
                project_id :: String.t(),
                test_id :: String.t(),
                filters :: any
              ) :: {:ok, Front.Models.TestExplorer.DetailedFlakyTest.t()} | {:error, any}

    @callback flaky_test_disruptions(
                org_id :: String.t(),
                project_id :: String.t(),
                test_id :: String.t(),
                page :: non_neg_integer(),
                page_size :: non_neg_integer(),
                filters :: any
              ) ::
                {:ok, {[Front.Models.TestExplorer.FlakyTestDisruption.t()], any()}}
                | {:error, any}

    @callback add_label(
                org_id :: String.t(),
                project_id :: String.t(),
                test_id :: String.t(),
                label :: String.t()
              ) :: {:ok, String.t()} | {:error, any}

    @callback remove_label(
                org_id :: String.t(),
                project_id :: String.t(),
                test_id :: String.t(),
                label :: String.t()
              ) :: {:ok, String.t()} | {:error, any}

    @callback resolve(
                org_id :: String.t(),
                project_id :: String.t(),
                test_id :: String.t(),
                user_id :: String.t()
              ) :: {:ok, String.t()} | {:error, any}

    @callback undo_resolve(
                org_id :: String.t(),
                project_id :: String.t(),
                test_id :: String.t(),
                user_id :: String.t()
              ) :: {:ok, String.t()} | {:error, any}

    @callback save_ticket_url(
                org_id :: String.t(),
                project_id :: String.t(),
                test_id :: String.t(),
                ticket_url :: String.t(),
                user_id :: String.t()
              ) :: {:ok, String.t()} | {:error, any}

    @callback webhook_settings(org_id :: String.t(), project_id :: String.t()) ::
                {:ok, Front.Models.TestExplorer.WebhookSettings.t()} | {:error, any}

    @callback create_webhook_settings(
                org_id :: String.t(),
                project_id :: String.t(),
                webhook_url :: String.t(),
                branches :: String.t(),
                enabled :: boolean(),
                greedy :: boolean()
              ) :: {:ok, Front.Models.TestExplorer.WebhookSettings.t()} | {:error, any}

    @callback update_webhook_settings(
                org_id :: String.t(),
                project_id :: String.t(),
                webhook_url :: String.t(),
                branches :: String.t(),
                enabled :: boolean(),
                greedy :: boolean()
              ) :: :ok | {:error, any}

    @callback delete_webhook_settings(org_id :: String.t(), project_id :: String.t()) ::
                :ok | {:error, any}
  end

  {client, _client_opts} = Application.compile_env!(:front, :superjerry_client)

  @behaviour Behaviour

  @impl Behaviour
  defdelegate list_flaky_tests(
                org_id,
                project_id,
                page,
                page_size,
                sort_field,
                sort_dir,
                filters
              ),
              to: client

  @impl Behaviour
  defdelegate list_disruption_history(org_id, project_id, filters), to: client

  @impl Behaviour
  defdelegate list_flaky_history(org_id, project_id, filters), to: client

  @impl Behaviour
  defdelegate flaky_test_details(org_id, project_id, test_id, filters), to: client

  @impl Behaviour
  defdelegate flaky_test_disruptions(org_id, project_id, test_id, page, page_size, filters),
    to: client

  @impl Behaviour
  defdelegate add_label(org_id, project_id, test_id, label), to: client

  @impl Behaviour
  defdelegate remove_label(org_id, project_id, test_id, label), to: client

  @impl Behaviour
  defdelegate resolve(org_id, project_id, test_id, user_id), to: client

  @impl Behaviour
  defdelegate undo_resolve(org_id, project_id, test_id, user_id), to: client

  @impl Behaviour
  defdelegate save_ticket_url(org_id, project_id, test_id, ticket_url, user_id), to: client

  @impl Behaviour
  defdelegate webhook_settings(org_id, project_id), to: client

  @impl Behaviour
  defdelegate create_webhook_settings(org_id, project_id, webhook_url, branches, enabled, greedy),
    to: client

  @impl Behaviour
  defdelegate update_webhook_settings(org_id, project_id, webhook_url, branches, enabled, greedy),
    to: client

  @impl Behaviour
  defdelegate delete_webhook_settings(org_id, project_id), to: client
end
