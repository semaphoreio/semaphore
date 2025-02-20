class String

  def super_encode_to_utf8
    force_encoding("utf-8")
      .encode("utf-16", :undef => :replace, :invalid => :replace, :replace => "")
      .encode("utf-8")
  end

  def super_encode_to_utf8!
    force_encoding("utf-8")
      .encode!("utf-16", :undef => :replace, :invalid => :replace, :replace => "")
      .encode!("utf-8")
  end

end
