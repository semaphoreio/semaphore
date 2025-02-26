# rubocop:disable all

class Policy::GoVersion < Policy
  MINIMUM_VERSION_REQUIRED = 20

  def initialize(args)
    super(args)
  end

  def test
    version_line = `cat go.mod | grep 'go 1.'`.strip
    if not version_line =~ /go 1.(\d+)/
      @output = "Unable to find Go version used: #{version_line}"
      return false
    end

    match = /go 1.(\d+)/.match(version_line)
    version = match[1].to_i
    if version < MINIMUM_VERSION_REQUIRED
      @output = "Go version used (#{version}) is below the minimum required (#{MINIMUM_VERSION_REQUIRED})"
      return false
    end

    return true
  end

  def reason
    @output
  end

  def dependencies
    []
  end
end
