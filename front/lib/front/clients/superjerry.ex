defmodule Front.Clients.Superjerry do
  require Logger

  alias InternalApi.Superjerry.{
    AddLabelRequest,
    CreateWebhookSettingsRequest,
    DeleteLabelRequest,
    DeleteWebhookSettingsRequest,
    FlakyTestDetailsRequest,
    FlakyTestDisruptionsRequest,
    ListDisruptionHistoryRequest,
    ListFlakyHistoryRequest,
    ListFlakyTestsRequest,
    Pagination,
    ResolveFlakyTestRequest,
    SaveTicketUrlRequest,
    Sort,
    UnresolveFlakyTestRequest,
    UpdateWebhookSettingsRequest,
    WebhookSettingsRequest
  }

  alias Front.Models.TestExplorer.{
    DetailedFlakyTest,
    FlakyTestDisruption,
    FlakyTestItem,
    HistoryItem,
    WebhookSettings
  }

  @behaviour Front.Superjerry.Behaviour

  @impl Front.Superjerry.Behaviour
  def list_flaky_tests(
        org_id,
        project_id,
        page,
        page_size,
        sort_field,
        sort_dir,
        filters
      ) do
    p = String.to_integer(page)
    ps = String.to_integer(page_size)

    %ListFlakyTestsRequest{
      org_id: org_id,
      project_id: project_id,
      filters: filters,
      pagination: %Pagination{
        page: p,
        page_size: ps
      },
      sort: %Sort{
        name: sort_field,
        dir: if(sort_dir == "asc", do: 0, else: 1)
      }
    }
    |> grpc_call(:list_flaky_tests)
    |> case do
      {:ok, result} ->
        flaky_tests =
          result.flaky_tests
          |> structs_to_maps()
          |> Enum.map(&FlakyTestItem.from_proto/1)

        pagination = extract_pagination(result)

        {:ok, {flaky_tests, pagination}}

      err ->
        Logger.error("Error listing flaky tests for proj #{project_id}:  #{inspect(err)}")
        {:error, "failed to fetch flaky tests"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def list_disruption_history(org_id, project_id, filters) do
    %ListDisruptionHistoryRequest{
      org_id: org_id,
      project_id: project_id,
      filters: filters
    }
    |> grpc_call(:list_disruption_history)
    |> case do
      {:ok, result} ->
        disruptions = structs_to_maps(result.disruptions)
        history = Enum.map(disruptions, &HistoryItem.from_proto/1)

        {:ok, history}

      err ->
        Logger.error("Error listing disruption history for proj #{project_id}:  #{inspect(err)}")

        {:error, "failed to fetch disruption history"}
    end
  end

  defp struct_to_map(nil), do: %{}

  defp struct_to_map(record), do: Map.from_struct(record)

  defp structs_to_maps([]), do: %{}

  defp structs_to_maps(records) do
    Enum.map(records, &struct_to_map/1)
  end

  @impl Front.Superjerry.Behaviour
  def list_flaky_history(org_id, project_id, filters) do
    %ListFlakyHistoryRequest{
      org_id: org_id,
      project_id: project_id,
      filters: filters
    }
    |> grpc_call(:list_flaky_history)
    |> case do
      {:ok, result} ->
        disruptions = structs_to_maps(result.disruptions)
        history = Enum.map(disruptions, &HistoryItem.from_proto/1)

        {:ok, history}

      err ->
        Logger.error("Error listing flaky history for proj #{project_id}:  #{inspect(err)}")
        {:error, "failed to fetch flaky history"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def flaky_test_details(org_id, project_id, test_id, filters) do
    %FlakyTestDetailsRequest{
      org_id: org_id,
      project_id: project_id,
      test_id: test_id,
      filters: filters
    }
    |> grpc_call(:flaky_test_details)
    |> case do
      {:ok, result} ->
        flaky_test_detail = DetailedFlakyTest.from_proto(result.detail)

        {:ok, flaky_test_detail}

      err ->
        Logger.error("Error fetch flaky history for proj #{project_id}:  #{inspect(err)}")
        {:error, "failed to fetch flaky history"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def flaky_test_disruptions(org_id, project_id, test_id, page, page_size, filters) do
    p = String.to_integer(page)
    ps = String.to_integer(page_size)

    %FlakyTestDisruptionsRequest{
      org_id: org_id,
      project_id: project_id,
      test_id: test_id,
      filters: filters,
      pagination: %Pagination{
        page: p,
        page_size: ps
      }
    }
    |> grpc_call(:flaky_test_disruptions)
    |> case do
      {:ok, result} ->
        disruptions = structs_to_maps(result.disruptions)

        flaky_test_disruptions =
          Enum.map(disruptions, &FlakyTestDisruption.from_proto/1)
          |> Enum.reject(&is_nil/1)

        pagination = extract_pagination(result)

        {:ok, {flaky_test_disruptions, pagination}}

      err ->
        Logger.error("Error flaky test disruptions to proj #{project_id}:  #{inspect(err)}")
        {:error, "failed to fetch flaky test disruptions"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def add_label(_org_id, project_id, test_id, label) do
    %AddLabelRequest{
      label: label,
      project_id: project_id,
      test_id: test_id
    }
    |> grpc_call(:add_label)
    |> case do
      {:ok, _} ->
        {:ok, label}

      err ->
        Logger.error("Error adding label to proj #{project_id}:  #{inspect(err)}")
        {:error, "failed to add label"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def remove_label(_org_id, project_id, test_id, label) do
    %DeleteLabelRequest{
      label: label,
      project_id: project_id,
      test_id: test_id
    }
    |> grpc_call(:delete_label)
    |> case do
      {:ok, _} ->
        {:ok, label}

      err ->
        Logger.error("Error deleting label to proj #{project_id}:  #{inspect(err)}")
        {:error, "failed to delete label"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def save_ticket_url(_org_id, project_id, test_id, ticket_url, user_id) do
    %SaveTicketUrlRequest{
      user_id: user_id,
      project_id: project_id,
      test_id: test_id,
      ticket_url: ticket_url
    }
    |> grpc_call(:save_ticket_url)
    |> case do
      {:ok, _} ->
        {:ok, ticket_url}

      err ->
        Logger.error(
          "Error saving ticket to proj #{project_id} - test: #{test_id}:  #{inspect(err)}"
        )

        {:error, "failed to save ticket url for Test: #{test_id}"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def resolve(_org_id, project_id, test_id, user_id) do
    %ResolveFlakyTestRequest{
      user_id: user_id,
      project_id: project_id,
      test_id: test_id
    }
    |> grpc_call(:resolve_flaky_test)
    |> case do
      {:ok, _} ->
        {:ok, "resolve"}

      err ->
        Logger.error("Error resolving test: #{test_id}:  #{inspect(err)}")
        {:error, "failed resolve test: #{test_id}"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def undo_resolve(_org_id, project_id, test_id, user_id) do
    %UnresolveFlakyTestRequest{
      user_id: user_id,
      project_id: project_id,
      test_id: test_id
    }
    |> grpc_call(:unresolve_flaky_test)
    |> case do
      {:ok, _} ->
        {:ok, "undo_resolve"}

      err ->
        Logger.error("Error unresolve test: #{test_id}:  #{inspect(err)}")
        {:error, "failed to unresolve test: #{test_id}"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def webhook_settings(org_id, project_id) do
    %WebhookSettingsRequest{
      org_id: org_id,
      project_id: project_id
    }
    |> grpc_call(:webhook_settings)
    |> case do
      {:ok, result} ->
        ws =
          result.settings
          |> struct_to_map()
          |> WebhookSettings.from_proto()

        {:ok, ws}

      err ->
        Logger.error(
          "Failed to load webhook settings for: org #{org_id}: proj #{project_id} #{inspect(err)}"
        )

        {:error, "failed to load webhook settings: #{project_id}"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def create_webhook_settings(org_id, project_id, webhook_url, branches, enabled, greedy) do
    %CreateWebhookSettingsRequest{
      org_id: org_id,
      project_id: project_id,
      webhook_url: webhook_url,
      branches: branches,
      enabled: enabled,
      greedy: greedy
    }
    |> grpc_call(:create_webhook_settings)
    |> case do
      {:ok, result} ->
        ws =
          result.settings
          |> struct_to_map()
          |> WebhookSettings.from_proto()

        {:ok, ws}

      err ->
        Logger.error(
          "Failed to create webhook settings for: org #{org_id}: proj #{project_id} #{inspect(err)}"
        )

        {:error, "failed to create webhook settings: #{project_id}"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def update_webhook_settings(org_id, project_id, webhook_url, branches, enabled, greedy) do
    %UpdateWebhookSettingsRequest{
      org_id: org_id,
      project_id: project_id,
      webhook_url: webhook_url,
      branches: branches,
      enabled: enabled,
      greedy: greedy
    }
    |> grpc_call(:update_webhook_settings)
    |> case do
      {:ok, _} ->
        :ok

      err ->
        Logger.error("Failed to update webhook settings for: proj #{project_id} #{inspect(err)}")

        {:error, "failed to update webhook settings: project #{project_id}"}
    end
  end

  @impl Front.Superjerry.Behaviour
  def delete_webhook_settings(org_id, project_id) do
    %DeleteWebhookSettingsRequest{
      org_id: org_id,
      project_id: project_id
    }
    |> grpc_call(:delete_webhook_settings)
    |> case do
      {:ok, _} ->
        :ok

      err ->
        Logger.error(
          "Failed to delete webhook settings for: org #{org_id}: proj #{project_id} #{inspect(err)}"
        )

        {:error, "failed to delete webhook settings: #{project_id}"}
    end
  end

  defp grpc_call(request, action) do
    Watchman.benchmark("superjerry.#{action}.duration", fn ->
      channel()
      |> call_grpc(
        InternalApi.Superjerry.Superjerry.Stub,
        action,
        request,
        metadata(),
        timeout()
      )
      |> tap(fn
        {:ok, _} -> Watchman.increment("superjerry.#{action}.success")
        {:error, _} -> Watchman.increment("superjerry.#{action}.failure")
      end)
    end)
  end

  defp call_grpc(error = {:error, err}, _, _, _, _, _) do
    Logger.error("""
    Unexpected error when connecting to Superjerry: #{inspect(err)}
    """)

    error
  end

  defp call_grpc({:ok, channel}, module, function_name, request, metadata, timeout) do
    apply(module, function_name, [channel, request, [metadata: metadata, timeout: timeout]])
  end

  defp channel do
    Application.fetch_env!(:front, :superjerry_grpc_endpoint)
    |> GRPC.Stub.connect()
  end

  defp timeout do
    15_000
  end

  defp metadata do
    nil
  end

  defp extract_pagination(result) do
    total_results = Integer.to_string(result.total_rows)
    total_pages = Integer.to_string(result.total_pages)

    %{
      total_pages: total_pages,
      total_results: total_results
    }
  end
end
