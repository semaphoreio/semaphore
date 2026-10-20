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

      # Every accepted token, mapped to its canonical option. Aliases map to the
      # same symbol as the option they stand for.
      OPTIONS = {
        "--include-secrets" => :include_secrets,
        "--enable-cache" => :enable_cache,
        "--include-cache" => :enable_cache
      }.freeze

      module_function

      def present?(body)
        !option_tokens(body).nil?
      end

      # Canonical, de-duplicated option symbols; empty unless present?.
      def options(body)
        Array(option_tokens(body)).map { |token| OPTIONS.fetch(token) }.uniq
      end

      # Tokens after the command when the whole comment is exactly one
      # column-zero command line with only known options; nil otherwise.
      def option_tokens(body)
        content_lines = body.to_s.split(/\r?\n/).map(&:rstrip).reject(&:empty?)
        return unless content_lines.length == 1

        line = content_lines.first
        return if line != line.lstrip

        command, *given_options = line.split(/[ \t]+/)
        return unless command == COMMAND
        return unless given_options.all? { |token| OPTIONS.key?(token) }

        given_options
      end
    end
  end
end
