module InternalApi::RepoProxy
  class PayloadFactory
    class InvalidReferenceError < StandardError; end

    BRANCH_PATTERN = %r(^refs\/heads\/)
    TAG_PATTERN = %r(^refs\/tags\/)
    PR_PATTERN = %r(^refs\/pull\/\d+$)

    def self.create(reference, sha)
      new(reference, sha).call
    end

    def initialize(reference, sha)
      @reference = reference
      @sha = sha
    end

    def call
      if BRANCH_PATTERN.match?(reference)
        InternalApi::RepoProxy::BranchPayload.new(reference, sha)
      elsif TAG_PATTERN.match?(reference)
        InternalApi::RepoProxy::TagPayload.new(reference)
      elsif PR_PATTERN.match?(reference)
        InternalApi::RepoProxy::PrPayload.new(reference, reference.split("/").last)
      else
        raise InvalidReferenceError, "Reference #{reference} is unsupported"
      end
    end

    private

    attr_reader :reference, :sha
  end
end
