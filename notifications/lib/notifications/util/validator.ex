defmodule Notifications.Util.Validator do
  alias Notifications.Models.Pattern

  def validate(notification, user_id) do
    with {:ok, :valid} <- validate_regex_patterns(notification),
         {:ok, :valid} <- validate_result_patterns(notification),
         {:ok, :valid} <- validate_notification_targets(notification),
         {:ok, :valid} <- validate_user_id(user_id) do
      {:ok, :valid}
    else
      e -> e
    end
  end

  defp validate_user_id(user_id) do
    case Ecto.UUID.cast(user_id) do
      {:ok, _} -> {:ok, :valid}
      :error -> {:error, :invalid_argument, "Invalid user_id: expected a valid UUID"}
    end
  end

  def validate_notification_targets(notification = %InternalApi.Notifications.Notification{}),
    do: validate_notification_targets_(notification.rules)

  def validate_notification_targets(
        notification = %Semaphore.Notifications.V1alpha.Notification{}
      ),
      do: validate_notification_targets_(notification.spec.rules)

  defp validate_notification_targets_(rules) do
    rules
    |> Enum.reduce_while({:ok, :valid}, fn rule, _acc ->
      case validate_rule_notification_targets(rule.notify) do
        {:ok, :valid} -> {:cont, {:ok, :valid}}
        e -> {:halt, e}
      end
    end)
  end

  def validate_rule_notification_targets(nil),
    do: {:error, :invalid_argument, "A notification rule must have a notify field."}

  def validate_rule_notification_targets(notify) do
    if has_valid_email_target?(notify.email) ||
         has_valid_target?(notify.slack) ||
         has_valid_target?(notify.webhook) do
      {:ok, :valid}
    else
      {:error, :invalid_argument,
       "A notification rule must have at least one notification target configured."}
    end
  end

  def has_valid_email_target?(nil), do: false
  def has_valid_email_target?(target), do: !Enum.empty?(target.cc)

  def has_valid_target?(nil), do: false
  def has_valid_target?(target), do: target.endpoint != nil && target.endpoint != ""

  def validate_regex_patterns(notification) do
    patterns = extract_all_patterns(notification)

    invalid_regex_patterns =
      Enum.filter(patterns, fn p ->
        if Pattern.regex?(p) do
          case Regex.compile(String.slice(p, 1..-2)) do
            {:ok, _} -> false
            _e -> true
          end
        else
          false
        end
      end)

    if invalid_regex_patterns == [] do
      {:ok, :valid}
    else
      if Enum.count(invalid_regex_patterns) == 1 do
        {
          :error,
          :invalid_argument,
          "Pattern #{hd(invalid_regex_patterns)} is not a valid regex statement"
        }
      else
        {
          :error,
          :invalid_argument,
          "Patterns [#{Enum.join(invalid_regex_patterns, ", ")}] are not valid regex statements"
        }
      end
    end
  end

  def extract_all_patterns(notification = %InternalApi.Notifications.Notification{}),
    do: extract_all_patterns_(notification.rules)

  def extract_all_patterns(notification = %Semaphore.Notifications.V1alpha.Notification{}),
    do: extract_all_patterns_(notification.spec.rules)

  defp extract_all_patterns_(rules) do
    rules
    |> Enum.flat_map(fn rule ->
      rule.filter.projects ++
        rule.filter.branches ++
        rule.filter.pipelines ++
        rule.filter.blocks ++
        rule.filter.results
    end)
  end

  def validate_result_patterns(notification = %InternalApi.Notifications.Notification{}),
    do: validate_result_patterns_(notification.rules)

  def validate_result_patterns(notification = %Semaphore.Notifications.V1alpha.Notification{}),
    do: validate_result_patterns_(notification.spec.rules)

  def validate_result_patterns_(rules) do
    rules
    |> Enum.flat_map(fn rule -> rule.filter.results end)
    |> filter_invalid_validations
    |> report_results
  end

  def report_results([]), do: {:ok, :valid}
  def report_results([invalid_result]), do: invalid_result

  def report_results(invalid_results) do
    {
      :error,
      :invalid_argument,
      "[#{Enum.join(invalid_results, ", ")}] are not valid result entries. Valid values are: passed, failed, canceled, stopped."
    }
  end

  def validate_result(entry) when entry in ["passed", "failed", "stopped", "canceled"],
    do: {:ok, :valid}

  def validate_result(invalid_result) do
    # canceled is not implemented yet as a pipeline result

    {
      :error,
      :invalid_argument,
      "Value #{invalid_result} is not a valid result entry. Valid values are: passed, failed, canceled, stopped."
    }
  end

  def skip_regex_result_entries(patterns) do
    patterns
    |> Enum.filter(fn term -> not Pattern.regex?(term) end)
  end

  def filter_invalid_validations(patterns) do
    patterns
    |> skip_regex_result_entries
    |> Enum.filter(fn entry -> validate_result(entry) != {:ok, :valid} end)
    |> Enum.map(&validate_result(&1))
  end
end
