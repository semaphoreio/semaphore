defmodule Notifications.Util.Transforms do
  def decode_spec(spec, Semaphore.Notifications.V1alpha.Notification.Spec) do
    transformations = %{
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status =>
        {__MODULE__, :public_n_to_atom},
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email =>
        {__MODULE__, :public_nil_to_email}
    }

    Util.Proto.deep_new!(
      Semaphore.Notifications.V1alpha.Notification.Spec,
      spec,
      string_keys_to_atoms: true,
      transformations: transformations
    )
  end

  def decode_spec(rules, InternalApi.Notifications.Notification.Rule) do
    transformations = %{
      InternalApi.Notifications.Notification.Rule.Notify.Status =>
        {__MODULE__, :private_n_to_atom},
      InternalApi.Notifications.Notification.Rule.Notify.Email =>
        {__MODULE__, :private_nil_to_email},
      InternalApi.Notifications.Notification.Rule.Filter.Results =>
        {__MODULE__, :private_n_to_atom}
    }

    Enum.map(rules, fn rule ->
      Util.Proto.deep_new!(
        InternalApi.Notifications.Notification.Rule,
        rule,
        string_keys_to_atoms: true,
        transformations: transformations
      )
    end)
  end

  def encode_spec(spec = %Semaphore.Notifications.V1alpha.Notification.Spec{}) do
    tf = %{
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status =>
        {__MODULE__, :atom_to_string}
    }

    Util.Proto.to_map!(spec, string_keys: true, transformations: tf)
  end

  def encode_spec(%{rules: rules}) do
    tf = %{
      InternalApi.Notifications.Notification.Rule.Notify.Status => {__MODULE__, :atom_to_string}
    }

    %{
      rules:
        Enum.map(rules, fn rule ->
          Util.Proto.to_map!(rule, string_keys: true, transformations: tf)
        end)
    }
  end

  def encode_notify(notify = %InternalApi.Notifications.Notification.Rule.Notify{}) do
    %{
      slack: internal_encode_proto(notify.slack),
      email: internal_encode_proto(notify.email),
      webhook: internal_encode_proto(notify.webhook)
    }
  end

  def encode_notify(notify = %Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify{}) do
    %{
      slack: public_encode_proto(notify.slack),
      email: public_encode_proto(notify.email),
      webhook: public_encode_proto(notify.webhook)
    }
  end

  def public_encode_proto(nil), do: nil

  def public_encode_proto(proto) do
    tf = %{
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status =>
        {__MODULE__, :atom_to_string}
    }

    Util.Proto.to_map!(proto, string_keys: true, transformations: tf)
  end

  def internal_encode_proto(nil), do: nil

  def internal_encode_proto(proto) do
    tf = %{
      InternalApi.Notifications.Notification.Rule.Notify.Status => {__MODULE__, :atom_to_string}
    }

    Util.Proto.to_map!(proto, string_keys: true, transformations: tf)
  end

  def atom_to_string(_name, value) do
    value |> Atom.to_string()
  end

  # for public_api

  def public_nil_to_email(_, nil),
    do: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email.new()

  def public_nil_to_email(_, value) do
    transformations = %{
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status =>
        {__MODULE__, :public_n_to_atom}
    }

    Util.Proto.deep_new!(
      Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Email,
      value,
      string_keys_to_atoms: true,
      transformations: transformations
    )
  end

  def public_n_to_atom(_field_name, string) when is_binary(string),
    do: string |> String.upcase() |> String.to_atom()

  def public_n_to_atom(_field_name, key) when is_integer(key),
    do: Semaphore.Notifications.V1alpha.Notification.Spec.Rule.Notify.Status.value(key)

  # transform functions for internal_api
  def private_nil_to_email(_, nil),
    do: InternalApi.Notifications.Notification.Rule.Notify.Email.new()

  def private_nil_to_email(_, value) do
    transformations = %{
      InternalApi.Notifications.Notification.Rule.Notify.Status =>
        {__MODULE__, :private_n_to_atom}
    }

    Util.Proto.deep_new!(
      InternalApi.Notifications.Notification.Rule.Notify.Email,
      value,
      string_keys_to_atoms: true,
      transformations: transformations
    )
  end

  def private_n_to_atom(_field_name, string) when is_binary(string),
    do: string |> String.upcase() |> String.to_atom()

  def private_n_to_atom(:status, key) when is_integer(key),
    do: InternalApi.Notifications.Notification.Rule.Notify.Status.value(key)

  def private_n_to_atom(:results, key) when is_integer(key),
    do: InternalApi.Notifications.Notification.Rule.Filter.Results.value(key)
end
