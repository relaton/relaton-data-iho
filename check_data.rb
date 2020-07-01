# frozen_string_literal: true

require 'yaml'
require 'relaton_iho'

def compare(src, dest)
  if src.is_a? Array
    result = src.map.with_index { |s, i| compare s, array(dest)[i] }
    compact result
  elsif src.is_a? String
    src != dest && "- #{src}\n+ #{dest}"
  elsif src.is_a? Hash
    result = src.map do |k, v|
      if v.is_a?(String) then message(k, v, dest)
      else
        res = compare v, dest[k]
        { k => res } if res&.any?
      end
    end
    compact result
  end
end

def message(key, val, dest)
  return unless !dest || dest[key] != val

  msg = "- #{key}: #{val}"
  msg += "\n+ #{key}: #{dest[key]}" if dest
  msg
end

def compact(arr)
  result = arr.select { |v| v }
  return unless result.any?

  result
end

def array(arg)
  arg.is_a?(Array) ? arg : [arg]
end

def print_msg(messages)
  if messages.is_a? Hash
    messages.each do |k, v|
      puts k + ':'
      if v.is_a?(String)
        puts "  #{v}"
      else
        print_msg v
      end
    end
  else
    messages.each do |msg|
      if msg.is_a? String
        puts msg
      else print_msg msg
      end
    end
  end
end

errors = false
Dir['data/*.{yaml,ymo}'].each do |f|
  begin
    # print "Parsing file: #{f}... "
    yaml = YAML.load_file(f)
    hash = RelatonIho::HashConverter.hash_to_bib yaml
    item = RelatonIho::IhoBibliographicItem.new hash
    if (messages = compare(yaml, item.to_hash))&.any?
      errors = true
      puts "Parsing #{f} failed. Parsed content doesn't match to source."
      print_msg messages
      puts
    # else
    #   puts "successfull. Document id: #{item.docidentifier.first.id}"
    end
  rescue ArgumentError => e
    errors = true
    puts "Parsing #{f} failed. Error: #{e.message}."
    puts e.backtrace
    puts
  end
end

exit(1) if errors
