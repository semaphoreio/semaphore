# rubocop:disable all

class Policy::TrivyImage < Policy
  def initialize(args)
    super(args)

    if !args.key?(:image)
      raise "Image is required"
    end

    @image = args[:image]
    @severity = args[:severity] || "HIGH,CRITICAL"
    @ignore_policy = args[:ignore_policy] || nil
    @scanners = args[:scanners] || "vuln,secret,license,misconfig"

    @skip_files = args[:skip_files].to_s.split(",") || []
    @skip_dirs = args[:skip_dirs].to_s.split(",") || []
    @scanners = args[:scanners]
  end

  def test
    command = [
      "trivy",
      "image",
      "--exit-code 1",
      "--severity #{@severity}",
      "--exit-on-eol 1",
      "--ignore-unfixed",
      "--scanners #{@scanners}",
      "--format json",
      "--output out/docker-scan-trivy.json"
    ]

    if @ignore_policy != nil
      command << "--ignore-policy #{@ignore_policy}"
    end

    @skip_files.each do |skip_file|
      command << "--skip-files #{skip_file}"
    end

    @skip_dirs.each do |skip_dir|
      command << "--skip-dirs #{skip_dir}"
    end

    command << "#{@image}"

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
