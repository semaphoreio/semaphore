# frozen_string_literal: true

module RepoHost
  module Github
    # Single source of truth for parsing `/sem-approve` comment commands.
    #
    # Shared by RepoHost::Github::Payload (authoritative) and
    # Semaphore::RepoHost::Github::WebhookFilter (coarse entry filter) so the
    # two can never drift apart — a drift where the filter is stricter than the
    # payload would silently drop valid approvals, and the reverse would let a
    # comment be recorded and then approved on looser terms than the filter
    # believed it had matched.
    #
    # `/sem-approve` grants production secrets and/or writable cache to
    # externally-authored fork code, so the parser is deliberately strict and
    # fails closed:
    #
    #   * the command must be the FIRST token of a line (after leading
    #     whitespace) — this rejects blockquotes (`> /sem-approve`, i.e. a
    #     GitHub "quote reply" of a maintainer's approval), inline code
    #     (`` `/sem-approve` ``) and any prose that merely mentions the command;
    #   * lines inside fenced code blocks (``` / ~~~) are ignored entirely, so
    #     quoting the command in a code fence does not trigger an approval;
    #   * a command line may carry ONLY recognized options — any unknown token
    #     invalidates the whole line rather than being silently discarded, so a
    #     mistyped flag cannot spend the one-shot approval with the flag dropped.
    module ApprovalCommand
      COMMAND = "/sem-approve"

      INCLUDE_SECRETS_OPTION = "--include-secrets"
      ENABLE_CACHE_OPTION = "--enable-cache"

      # Backwards-compatible alias. The original task specification (and older
      # drafts of the docs) used `--include-cache`; the implemented flag is
      # `--enable-cache`. Accept both and normalize to the canonical spelling so
      # a maintainer following the older contract does not silently consume the
      # approval with the cache flag quietly ignored.
      ENABLE_CACHE_ALIAS = "--include-cache"
      OPTION_ALIASES = { ENABLE_CACHE_ALIAS => ENABLE_CACHE_OPTION }.freeze

      # Canonical options callers may test for.
      KNOWN_OPTIONS = [INCLUDE_SECRETS_OPTION, ENABLE_CACHE_OPTION].freeze
      # Tokens accepted on a command line (canonical options + aliases).
      RECOGNIZED_TOKENS = (KNOWN_OPTIONS + OPTION_ALIASES.keys).freeze

      FENCE_DELIMITERS = ["```", "~~~"].freeze

      module_function

      # True when `body` contains at least one valid whole-line approval command.
      def present?(body)
        command_lines(body).any?
      end

      # Unique, canonicalized options requested across every command line.
      def options(body)
        command_lines(body).flat_map { |tokens| tokens.drop(1) }.uniq
      end

      # Array of token arrays, one per line that is exactly an approval command
      # (optionally followed only by recognized options). Options are returned
      # in canonical form.
      def command_lines(body)
        in_fence = false

        body.to_s.split(/\r?\n/).map do |line|
          if fence_delimiter?(line.strip)
            in_fence = !in_fence
            next
          end
          next if in_fence

          tokens_from_line(line)
        end.compact
      end

      def fence_delimiter?(stripped_line)
        stripped_line.start_with?(*FENCE_DELIMITERS)
      end

      def tokens_from_line(line)
        # The command must begin at column zero. A leading space/tab means the
        # line is indented Markdown code (or otherwise not a deliberate command)
        # and must not trigger a privileged approval.
        return nil if line != line.lstrip

        tokens = line.strip.split(/[ \t]+/)
        return nil unless tokens.first == COMMAND

        options = tokens.drop(1)
        return nil unless options.all? { |token| RECOGNIZED_TOKENS.include?(token) }

        [COMMAND, *options.map { |token| OPTION_ALIASES.fetch(token, token) }]
      end
    end
  end
end
