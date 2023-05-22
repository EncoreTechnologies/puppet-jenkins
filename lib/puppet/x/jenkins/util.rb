require_relative '../jenkins'
require 'cgi'
require 'rexml/document'

module Puppet::X::Jenkins::Util
  def unundef(data)
    iterate(data) { |x| x == :undef ? nil : x }
  end
  module_function :unundef

  def undefize(data)
    iterate(data) { |x| x.nil? ? :undef : x }
  end
  module_function :undefize

  # loosely based on
  # https://stackoverflow.com/questions/16412013/iterate-nested-hash-that-contains-hash-and-or-array
  def iterate(data, &block)
    return data unless block_given?

    case data
    when Hash
      data.transform_values do |v|
        iterate(v, &block)
      end
    when Array
      data.map { |v| iterate(v, &block) }
    else
      yield data
    end
  end
  module_function :iterate

  def hash_to_xml(h, indent: '', path: '')
    Puppet.debug("INSIDE HASH_TO_XML")
    res = ''
    h.each do |key_sym, value|
      next if value.nil?
      key = key_sym.to_s
      child_indent = indent + '  '
      full_path = path + key + '.'

      case value
      when Hash
        xml = hash_to_xml(value, indent: child_indent, path: full_path)
        res += if xml.empty?
                 "#{indent}<#{key}>\n#{indent}</#{key}>\n"
               else
                 "#{indent}<#{key}>\n#{xml}\n#{indent}</#{key}>\n"
               end
      when Integer, Float, String, true, false
        res += primitive_to_xml(value, key, indent: indent)
      when Array
        res += array_to_xml(value, key, indent: indent, path: full_path)
      else
        cls = value.class.name
        path_key = path + key
        raise "Unsupported hash_to_xml value type=#{cls} for key=#{path_key} value=#{value}"
      end
    end
    res.rstrip
  end

  def array_to_xml(a, key, indent: '', path: '')
    Puppet.debug("INSIDE ARRAY_TO_XML")
    res = ''
    a.each do |value|
      next if value.nil?
      child_indent = indent + '  '
      full_path = path + key + '.'

      case value
      when Hash
        xml = hash_to_xml(value, indent: child_indent, path: full_path)
        res += "#{indent}<#{key}>\n#{xml}\n#{indent}</#{key}>\n"
      when Integer, Float, String, true, false
        res += primitive_to_xml(value, key, indent: indent)
      when Array
        path_key = path + key
        raise "We currently dont support nested arrays: key=#{path_key} value=#{value}"
      else
        cls = value.class.name
        path_key = path + key
        raise "Unsupported array_to_xml value type=#{cls} for key=#{path_key} value=#{value}"
      end
    end
    res.rstrip
  end

  def primitive_to_xml(value, key, indent: '')
    Puppet.debug("INSIDE PRIM_TO_XML")
    # replace the following XML special characters
    # "   &quot;
    # '   &apos;
    # <   &lt;
    # >   &gt;
    # &   &amp;
    value_s = CGI.escapeHTML(value.to_s)
    "#{indent}<#{key}>#{value_s}</#{key}>\n"
  end

  def pretty_xml(str)
    Puppet.debug("INSIDE PRETTY_XML")
    doc = REXML::Document.new(str)
    formatter = REXML::Formatters::Pretty.new

    # Compact uses as little whitespace as possible
    formatter.compact = true
    resultstr = ''
    formatter.write(doc, resultstr)
    resultstr
  end
end
