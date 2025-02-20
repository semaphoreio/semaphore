class RegexpList
  def initialize(raw_list)
    @raw_list    = raw_list || ""
    @string_list = @raw_list.split
    @regexp_list = extract_regexp_list
  end

  def matches?(string)
    @regexp_list.any? { |r| string =~ r }
  end

  def valid?
    @valid ||= @string_list.all? { |line| valid_regex?(line) }
  end

  private

  def extract_regexp_list
    @string_list.map do |e|
      begin
        Regexp.new(e)
      rescue RegexpError
        # ignore invalid regexp
      end
    end
  end

  def valid_regex?(line)
    Regexp.new(line)
    true
  rescue RegexpError
    false
  end
end
