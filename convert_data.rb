#!/usr/bin/env ruby
# frozen_string_literal: true

# Convert IHO data files from old Relaton v1 format (on main branch) to new
# Lutaml::Model format, writing results to data/ on the current branch.
#
# Run from the relaton-iho gem directory:
#   bundle exec ruby /path/to/relaton-data-iho/convert_data.rb

require "relaton/iho"
require "relaton/iho/hash_parser_v1"
require "yaml"

REPO_DIR = File.expand_path(__dir__)
DATA_DIR = File.join(REPO_DIR, "data")
SOURCE_BRANCH = "main"

# p-6-3.yaml has docid "P-6" (same as p-6.yaml). Fix to "P-6-3".
DOCID_FIXES = {
  "p-6-3.yaml" => { "id" => "P-6-3", "docnumber" => "6-3" },
}.freeze

# p-7_1-0-9.yaml has edition "1.0.8" (should be "1.0.9").
EDITION_FIXES = {
  "p-7_1-0-9.yaml" => "1.0.9",
}.freeze

# p-6 files need edition added to filename to avoid collision.
FILE_RENAMES = {
  "p-6.yaml" => "p-6_1-0-0.yaml",
  "p-6-3.yaml" => "p-6-3_1-0-0.yaml",
}.freeze

def source_filenames
  output = `git -C #{REPO_DIR} ls-tree --name-only #{SOURCE_BRANCH} data/`
  output.lines.map { |l| File.basename(l.chomp) }.select { |f| f.end_with?(".yaml") }
end

def read_source(filename)
  `git -C #{REPO_DIR} show #{SOURCE_BRANCH}:data/#{filename}`
end

def expand_series_titles!(hash)
  return unless hash["series"].is_a?(Hash) && hash["series"]["title"].is_a?(Hash)

  title = hash["series"]["title"]
  return unless title["content"].is_a?(Array)

  type = title["type"]
  hash["series"]["title"] = title["content"].map do |t|
    { "content" => t["content"], "language" => t["language"],
      "script" => t["script"], "type" => type }.compact
  end
end

def apply_fixes!(hash, filename)
  # Normalize year-only revision_date (Date.parse doesn't handle "YYYY")
  if hash.dig("version", "revision_date")&.match?(/\A\d{4}\z/)
    hash["version"]["revision_date"] += "-01-01"
  end

  if DOCID_FIXES.key?(filename)
    fix = DOCID_FIXES[filename]
    hash["docid"]["id"] = fix["id"]
    hash["docnumber"] = fix["docnumber"]
  end

  if EDITION_FIXES.key?(filename)
    hash["edition"]["content"] = EDITION_FIXES[filename]
  end
end

def output_filename(filename)
  FILE_RENAMES.fetch(filename, filename)
end

def convert_file(filename)
  content = read_source(filename)
  hash = YAML.safe_load(content)
  return unless hash.is_a?(Hash)

  apply_fixes!(hash, filename)
  expand_series_titles!(hash)

  bib_hash = Relaton::Iho::HashParserV1.hash_to_bib(hash)
  item = Relaton::Iho::ItemData.new(**bib_hash)
  yaml = Relaton::Iho::Item.to_yaml(item)

  out = output_filename(filename)
  File.write(File.join(DATA_DIR, out), yaml)
end

FileUtils.mkdir_p(DATA_DIR)

filenames = source_filenames.sort
total = filenames.size
errors = []

filenames.each_with_index do |filename, idx|
  print "\r[#{idx + 1}/#{total}] Converting #{filename}..."
  begin
    convert_file(filename)
  rescue => e
    errors << { file: filename, error: e }
    warn "\n  ERROR in #{filename}: #{e.message}"
  end
end

puts "\nDone. Converted #{total - errors.size}/#{total} files."
if errors.any?
  puts "\nFailed files:"
  errors.each { |e| puts "  #{e[:file]}: #{e[:error].message}" }
end
