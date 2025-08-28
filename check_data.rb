#!/usr/bin/env ruby
## frozen_string_literal: true

require 'yaml'
require 'relaton_iho'

#
# Compare elements of source and destination
#
# @param [Array, String, Hash] src source element
# @param [Array, String, Hash] dest destination element
#
# @return [<Type>] <description>
#
def compare(src, dest, path = '') # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # Add nil check for dest to prevent undefined method errors
  if dest.nil?
    return ["- #{src.to_s[0..70]}#{src.to_s.size > 70 ? '...' : ''} (at #{path})",
            "+ nil (dest is nil at #{path})"]
  end

  if !src.is_a?(dest.class) && !(dest.is_a?(Array) || src.is_a?(Array)) && !(dest.respond_to?(:[]) && (dest['content'] || dest['type']))
    return ["- #{src.to_s[0..70]}#{src.to_s.size > 70 ? '...' : ''} (at #{path})",
            "+ #{dest.to_s[0..70]}#{dest.to_s.size > 70 ? '...' : ''} (at #{path})"]
  elsif dest.is_a?(Array)
    return compare src, dest.first, path
  elsif src.is_a?(Array)
    return compare src.first, dest, path
  end
  case src
  when Array
    result = src.map.with_index { |s, i| compare s, array(dest)[i], "#{path}[#{i}]" }
    compact result
  when String
    dest_str = case dest
               when Hash then dest['content'] || dest['type']
               when Array then dest[0] && dest[0]['content'] || dest[0] && dest[0]['type']
               else dest
               end
    src != dest_str && ["- #{src} (at #{path})", "+ #{dest_str} (at #{path})"]
  when Hash
    result = src.map do |k, v|
      current_path = path.empty? ? k.to_s : "#{path}.#{k}"
      if dest[k].nil?
        puts "WARNING: Key '#{k}' exists in source but is nil in dest at path: #{current_path}"
        next { k => ["- #{v} (at #{current_path})", "+ nil (missing in dest)"] }
      end
      dest[k]['begins'].sub!(/\s00:00$/, '') if k == 'validity' && dest[k].respond_to?(:[])
      res = compare v, dest[k], current_path
      { k => res } if res && !res.empty?
    end
    compact result
  end
rescue => e
  puts "ERROR during comparison at path '#{path}': #{e.message}"
  puts "Source: #{src.inspect}"
  puts "Dest: #{dest.inspect}"
  raise e
end

def compact(arr)
  result = arr.select { |v| v }
  return unless result.any?

  result
end

def array(arg)
  arg.is_a?(Array) ? arg : [arg]
end

#
# Prints diff between source and destination
#
# @param [Hash, Array] messages diff messages
# @param [String] indent indentation
#
# @return [<Type>] <description>
#
def print_msg(messages, indent = '') # rubocop:disable Metrics/MethodLength, Metrics/PerceivedComplexity
  if messages.is_a? Hash
    messages.each do |k, v|
      puts "#{indent}#{k}:"
      if v.is_a?(String)
        puts "#{indent}  #{v}"
      else
        print_msg v, "#{indent}  "
      end
    end
  else
    messages.each do |msg|
      if msg.is_a? String
        puts "#{indent}#{msg}"
      else
        print_msg msg, indent
      end
    end
  end
end

path = ARGV.first || 'data/*.{yaml,yml}'

errors = false
Dir[path].each do |f|
  yaml = YAML.load_file(f)
  hash = RelatonIho::HashConverter.hash_to_bib yaml
  item = RelatonIho::IhoBibliographicItem.new(**hash)
  if (messages = compare(yaml, item.to_hash))&.any?
    errors = true
    puts "Parsing #{f} failed. Parsed content doesn't match to source."
    print_msg messages
    puts
  end
  primary_id = item.docidentifier.detect(&:primary)
  unless primary_id
    errors = true
    puts "Parsing #{f} failed. No primary id."
  end
rescue ArgumentError, NoMethodError, TypeError => e
  errors = true
  puts "Parsing #{f} failed. Error: #{e.message}."
  puts e.backtrace
  puts
end

exit(1) if errors
