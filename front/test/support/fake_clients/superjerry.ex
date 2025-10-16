defmodule Support.FakeClients.Superjerry do
  @behaviour Front.Superjerry.Behaviour

  alias Front.Models.TestExplorer.{
    FlakyTestItem,
    HistoryItem
  }

  @impl Front.Superjerry.Behaviour
  def list_flaky_tests(
        _org_id \\ "",
        _project_id \\ "",
        _page \\ 1,
        _page_size \\ 100,
        _sort_field \\ "",
        _sort_dir \\ "",
        _filters \\ []
      ) do
    flaky_tests =
      1..20
      |> Enum.map(fn _ -> new_flaky_test() end)

    {:ok, {flaky_tests, stubbed_pagination(1, 20)}}
  end

  @impl Front.Superjerry.Behaviour
  def list_disruption_history(_org_id, _project_id, _filters) do
    disruption_history = history_items(Date.utc_today() |> Date.add(-30), Date.utc_today())
    {:ok, disruption_history}
  end

  @impl Front.Superjerry.Behaviour
  def list_flaky_history(_org_id, _project_id, _filters) do
    flaky_history = history_items(Date.utc_today() |> Date.add(-30), Date.utc_today())

    {:ok, flaky_history}
  end

  @impl Front.Superjerry.Behaviour
  def flaky_test_details(_org_id, _project_id, _test_id, _filters) do
    flaky_test_details = Front.Models.TestExplorer.DetailedFlakyTest.new(%{})

    {:ok, flaky_test_details}
  end

  @impl Front.Superjerry.Behaviour
  def flaky_test_disruptions(_org_id, _project_id, _test_id, _page, _page_size, _filters) do
    flaky_test_disruptions = []

    {:ok, {flaky_test_disruptions, stubbed_pagination()}}
  end

  @impl Front.Superjerry.Behaviour
  def add_label(_org_id, _project_id, _test_id, label) do
    {:ok, label}
  end

  @impl Front.Superjerry.Behaviour
  def remove_label(_org_id, _project_id, _test_id, label) do
    {:ok, label}
  end

  @impl Front.Superjerry.Behaviour
  def resolve(_org_id, _project_id, _test_id, _user_id) do
    {:ok, "resolve"}
  end

  @impl Front.Superjerry.Behaviour
  def undo_resolve(_org_id, _project_id, _test_id, _user_id) do
    {:ok, "undo_resolve"}
  end

  @impl Front.Superjerry.Behaviour
  def save_ticket_url(_org_id, _project_id, _test_id, url, _user_id) do
    {:ok, url}
  end

  @impl Front.Superjerry.Behaviour
  def webhook_settings(org_id, project_id) do
    {:ok,
     %Front.Models.TestExplorer.WebhookSettings{
       id: "1234-1234-12345-12345",
       org_id: org_id,
       project_id: project_id,
       webhook_url: "https://semaphore.semaphore.com/webhooks/processor",
       branches: ["main", "develop"],
       enabled: true
     }}
  end

  @impl Front.Superjerry.Behaviour
  def create_webhook_settings(org_id, project_id, _webhook_url, _branches, enabled, greedy) do
    {:ok,
     %Front.Models.TestExplorer.WebhookSettings{
       id: "1234-1234-12345-12345",
       org_id: org_id,
       project_id: project_id,
       webhook_url: "https://semaphore.semaphore.com/webhooks/processor",
       branches: ["main", "develop"],
       enabled: enabled,
       greedy: greedy
     }}
  end

  @impl Front.Superjerry.Behaviour
  def update_webhook_settings(_org_id, _project_id, _webhook_url, _branches, _enabled, _greedy) do
    :ok
  end

  @impl Front.Superjerry.Behaviour
  def delete_webhook_settings(_org_id, _project_id) do
    :ok
  end

  defp stubbed_pagination(total_results \\ 3, total_pages \\ 1) do
    %{
      first: "",
      prev: "",
      next: "",
      last: "",
      total_pages: "#{total_pages}",
      total_results: "#{total_results}"
    }
  end

  defp history_items(from, to) do
    Date.range(from, to)
    |> Enum.map(fn date ->
      HistoryItem.new(%{count: Faker.random_between(0, 10), day: date})
    end)
  end

  defp new_flaky_test(_opts \\ []) do
    today = Date.utc_today()
    first_flake = Faker.Date.between(today |> Date.add(-30), today)
    history = history_items(first_flake, today)
    disruption_count = Enum.map(history, & &1.count) |> Enum.sum()
    last_flake = history |> Enum.filter(&(&1.count != 0)) |> List.last() |> Map.get(:day)

    labels =
      0..Faker.random_between(0, 2)
      |> Enum.map(& &1)
      |> Enum.map(fn _ -> Faker.Commerce.product_name() end)

    %FlakyTestItem{
      test_id: Ecto.UUID.generate(),
      test_name: Faker.Lorem.sentence(6..12),
      test_group: Faker.Lorem.sentence(6..12),
      test_runner: Faker.Lorem.sentence(6..12),
      test_suite: Faker.Lorem.sentence(6..12),
      test_file: Faker.File.file_name(),
      disruptions_count: disruption_count,
      pass_rate: Faker.random_between(0, 100),
      labels: labels,
      latest_disruption_timestamp: last_flake,
      latest_disruption_hash:
        :crypto.hash(:sha256, Ecto.UUID.generate()) |> Base.encode16() |> String.downcase(),
      latest_disruption_run_id: Ecto.UUID.generate(),
      latest_disruption_job_url: "123",
      scheduled: false,
      resolved: false,
      disruption_history: history,
      ticket_url: "",
      first_disruption_at: first_flake,
      age: Timex.diff(Timex.now(), first_flake, :days)
    }
  end
end
