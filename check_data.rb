#!/usr/bin/env ruby
## frozen_string_literal: true

require 'yaml'
require 'relaton/iho'

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
      dest[k]['begins']&.sub!(/T00:00:00\+00:00$/, '') if k == 'validity' && dest[k].respond_to?(:[])
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

#
# Removes the differences that come from a newer relaton gem, not from a parse error
#
# @param [Hash] src source hash
# @param [Hash] dest destination hash
#
def normalize!(src, dest)
  [src, dest, src['ext'], dest['ext']].compact.each { |h| h.delete 'schema_version' }

  # The gem moves version revision_date and draft to content
  Array(src['version']).each do |v|
    next if v['content']

    parts = [v.delete('draft'), v.delete('revision_date')].compact
    v['content'] = parts.size == 2 ? "#{parts[0]} (#{parts[1]})" : parts.first
  end
end

path = ARGV.first || 'data/*.{yaml,yml}'

errors = false
Dir[path].each do |f|
  yaml = File.read(f, encoding: 'utf-8')
  hash1 = YAML.safe_load yaml
  item = Relaton::Iho::Item.from_yaml yaml
  hash2 = YAML.safe_load item.to_yaml
  normalize! hash1, hash2
  if (messages = compare(hash1, hash2))&.any?
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
rescue StandardError => e
  errors = true
  puts "Parsing #{f} failed. Error: #{e.message}."
  puts e.backtrace
  puts
end

exit(1) if errors
