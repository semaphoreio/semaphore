# rubocop:disable all

class Policy::TrivyConfig < Policy
  def initialize(args)
    super(args)
    if args[:skip_files]
      @skip_files = args[:skip_files].split(",")
    else
      @skip_files = ["Dockerfile.dev"]
    end

    @skip_dirs = args[:skip_dirs].to_s.split(",") || []
  end

  def test
    command = [
      "trivy",
      "config",
      "--exit-code 1"
    ]

    @skip_files.each do |skip_file|
      command << "--skip-files #{skip_file}"
    end

    @skip_dirs.each do |skip_dir|
      command << "--skip-dirs #{skip_dir}"
    end

    command << "."

    @output = `#{command.join(" ")}`
    $?.success?
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "trivy",
        install: Proc.new do
          `curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sudo sh -s -- -b /usr/local/bin`
          $?.exitstatus
        end
      }
    ]
  end
end
