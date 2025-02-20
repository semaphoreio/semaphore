defmodule Front.WorkflowPage.Errors do
  def has_errors?(pipeline) do
    is_binary(pipeline.error_description) && pipeline.error_description != ""
  end

  def tabs_used_for_indentation?(error) when is_binary(error) do
    String.contains?(error, "yamerl_parsing_error") && String.contains?(error, "\\t")
  end

  def is_structured_error?(error) do
    Front.WorkflowPage.Errors.StructuredError.parsable?(error)
  end
end
