require 'cgi'

class Mechanize::Util
  CODE_DIC = {
    :JIS => "ISO-2022-JP",
    :EUC => "EUC-JP",
    :SJIS => "SHIFT_JIS",
    :UTF8 => "UTF-8", :UTF16 => "UTF-16", :UTF32 => "UTF-32"}

  # true if RUBY_VERSION is 1.9.0 or later
  NEW_RUBY_ENCODING = RUBY_VERSION >= '1.9.0'

  # contains encoding error classes to raise
  ENCODING_ERRORS = if NEW_RUBY_ENCODING
                      [EncodingError]
                    else
                      [Iconv::InvalidEncoding, Iconv::IllegalSequence]
                    end

  def self.build_query_string(parameters, enc=nil)
    parameters.map { |k,v|
      # WEBrick::HTTP.escape* has some problems about m17n on ruby-1.9.*.
      [CGI.escape(k.to_s), CGI.escape(v.to_s)].join("=") if k
    }.compact.join('&')
  end

  # Converts string +s+ from +code+ to UTF-8.
  def self.from_native_charset(s, code, ignore_encoding_error=false, log=nil)
    return s unless s && code
    return s unless Mechanize.html_parser == Nokogiri::HTML

    begin
      encode_to(code, s)
    rescue *ENCODING_ERRORS => ex
      log.debug("from_native_charset: #{ex.class}: form encoding: #{code.inspect} string: #{s}") if log
      if ignore_encoding_error
        s
      else
        raise
      end
    end
  end

  # inner convert method of Util.from_native_charset
  def self.encode_to(encoding, str)
    if NEW_RUBY_ENCODING
      str.encode(encoding)
    else
      Iconv.conv(encoding.to_s, "UTF-8", str)
    end
  end
  private_class_method :encode_to

  def self.html_unescape(s)
    return s unless s
    s.gsub(/&(\w+|#[0-9]+);/) { |match|
      number = case match
               when /&(\w+);/
                 Mechanize.html_parser::NamedCharacters[$1]
               when /&#([0-9]+);/
                 $1.to_i
               end

      number ? ([number].pack('U') rescue match) : match
    }
  end

  def self.detect_charset(src)
    tmp = NKF.guess(src || "<html></html>")
    if RUBY_VERSION >= "1.9.0"
      enc = tmp.to_s.upcase
    else
      enc = NKF.constants.find{|c|
        NKF.const_get(c) == tmp
      }
      enc = CODE_DIC[enc.intern]
    end
    enc || "ISO-8859-1"
  end

  def self.uri_escape str, unsafe = nil
    @parser ||= begin
                  URI::Parser.new
                rescue NameError
                  URI
                end

    if URI == @parser then
      unsafe ||= URI::UNSAFE
    else
      unsafe ||= @parser.regexp[:UNSAFE]
    end

    @parser.escape str, unsafe
  end

  def self.uri_unescape str
    @parser ||= begin
                  URI::Parser.new
                rescue NameError
                  URI
                end

    @parser.unescape str
  end

end
