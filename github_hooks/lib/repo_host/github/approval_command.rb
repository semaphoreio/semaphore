# frozen_string_literal: true

module RepoHost
  module Github
    # Single source of truth for parsing `/sem-approve` comment commands.
    #
    # Shared by RepoHost::Github::Payload and
    # Semaphore::RepoHost::Github::WebhookFilter so the two can never disagree
    # about what counts as an approval.
    #
    # `/sem-approve` grants production secrets and/or writable cache to
    # externally-authored fork code, so the trigger surface is kept as small as
    # possible: the ENTIRE comment must be exactly the command, optionally
    # followed by recognized options, on a single line at column zero
    # (surrounding blank lines are tolerated). Anything else does NOT trigger an
    # approval — the command embedded in prose, a blockquote or quoted reply,
    # indented or fenced code (of ANY fence style/length, nested or unclosed),
    # an HTML comment (single- or multi-line), or the command spread across
    # multiple lines.
    #
    # Requiring the command to be the sole content of the comment deliberately
    # avoids interpreting Markdown at all. A partial fence/HTML-comment parser
    # gets nested/mismatched/longer fences and multi-line HTML comments wrong —
    # a command that GitHub still renders as code, or hides in a comment, can
    # slip through — and the only robust alternative (a full CommonMark parse of
    # the visible text) is far more machinery than a privileged one-shot command
    # warrants. "The whole comment is the command" has no such ambiguity.
    module ApprovalCommand
      COMMAND = "/sem-approve"

      INCLUDE_SECRETS_OPTION = "--include-secrets"
      ENABLE_CACHE_OPTION = "--enable-cache"

      # Backwards-compatible alias for --enable-cache (older docs/task spec used
      # `--include-cache`); normalized to the canonical spelling.
      ENABLE_CACHE_ALIAS = "--include-cache"
      OPTION_ALIASES = { ENABLE_CACHE_ALIAS => ENABLE_CACHE_OPTION }.freeze

      KNOWN_OPTIONS = [INCLUDE_SECRETS_OPTION, ENABLE_CACHE_OPTION].freeze
      # Tokens accepted after the command (canonical options + aliases).
      RECOGNIZED_TOKENS = (KNOWN_OPTIONS + OPTION_ALIASES.keys).freeze

      module_function

      # True only when the whole comment is exactly an approval command.
      def present?(body)
        !command_tokens(body).nil?
      end

      # Canonicalized, de-duplicated options requested by the command (empty
      # unless present?). Alias + canonical (e.g. --include-cache + --enable-cache)
      # collapse to a single canonical option.
      def options(body)
        (command_tokens(body) || []).drop(1).uniq
      end

      # Returns [COMMAND, *canonical_options] when the entire comment body is
      # exactly the command line, or nil otherwise. Any non-blank line other
      # than that single command line (prose, a code fence, an HTML comment, a
      # second command) makes the comment non-triggering.
      def command_tokens(body)
        content_lines = body.to_s.split(/\r?\n/).map(&:rstrip).reject(&:empty?)
        return nil unless content_lines.length == 1

        line = content_lines.first
        # The command must start at column zero: a leading space/tab means
        # indented (Markdown code) content, not a deliberate command.
        return nil if line != line.lstrip

        tokens = line.split(/[ \t]+/)
        return nil unless tokens.first == COMMAND

        given_options = tokens.drop(1)
        return nil unless given_options.all? { |token| RECOGNIZED_TOKENS.include?(token) }

        [COMMAND, *given_options.map { |token| OPTION_ALIASES.fetch(token, token) }]
      end
    end
  end
end
