# rubocop:disable all

class Policy::Gosec < Policy
  def initialize(args)
    super(args)
    @ignores = args[:ignores] || nil
    @conf = args[:config] || nil
  end

  def test
    commands = [
      "gosec",
      "-quiet",
      "-fmt=junit-xml",
      "-out=results.xml",
      "-stdout"
    ]

    if @ignores != nil
      commands << "-exclude #{@ignores}"
    end

    if @conf != nil
      commands << "#{@conf}"
    end

    commands << "./..."

    @output = `export PATH=/usr/local/go/bin:${PATH} && #{commands.join(" ")}`
    $?.success?
  end

  def reason
    @output
  end

  def dependencies
    [
      {
        name: "go",
        install: Proc.new do
          commands = [
            "wget -q https://golang.org/dl/go1.22.7.linux-amd64.tar.gz -P /tmp",
            "sudo tar -zxvf /tmp/go1.22.7.linux-amd64.tar.gz -C /usr/local/"
          ]

          `#{commands.join(" && ")}`
          $?.exitstatus
        end
      },
      {
        name: "gosec",
        install: Proc.new do
          `curl -sfL https://raw.githubusercontent.com/securego/gosec/master/install.sh | sudo sh -s -- -b /usr/local/bin v2.22.1`
          $?.exitstatus
        end
      }
    ]
  end
end
