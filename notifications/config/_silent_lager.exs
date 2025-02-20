use Mix.Config

#
# Lager is introduced by Tackle (amqp) dependancy.
# From AMQP's docs: "Lager is not a good friend with Elixir's logger".
#
# By default error_logger_redirect is true. This means that Lager will try to
# interpret the error log. This interpretation fails ofter, most commonly for
# Phonix and GRPC ranch controllers.
#
# When the interpretation fails two negative things happen:
#
#  - We send 2 errors to sentry, instead of 1
#  - In tests, Lager prints out 20+ poop lines. This hinders productivity in a TDD cycle.
#
# Per AMQP docs, we are disabling it:
#
#   link: https://hexdocs.pm/amqp/readme.html
#   search: "Log related to amqp supervisors are too verbose"
#
config :lager,
  error_logger_redirect: false,
  handlers: [level: :critical]
