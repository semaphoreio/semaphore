class Semaphore::RepoHost::Hooks::Handler

  # A hook carried in Worker's job arguments: verified on every run, and handed on by
  # enqueuing another Worker job with the same body and signature.
  JobArguments = Struct.new(:body, :signature, :retries, :stale_attempts) do
    def verified?
      false
    end

    def reschedule(workflow_id, delay, retries, stale_attempts)
      args = [workflow_id, body, signature, retries, *Array(stale_attempts.nonzero?)]

      if delay.positive?
        Worker.perform_in(delay, *args)
      else
        Worker.perform_async(*args)
      end
    end
  end

end
