# frozen_string_literal: true
#
# Generates the legacy indexes from the data YAML:
#   index-v1 — "DOCID EDITION" string index
#   index-v2 — flat pubid-iho (pubid v1) hash, e.g.
#              {publisher: "IHO", number: "100", type: "S", version: "5.2.0"}
#
# Uses pubid-iho (pubid v1), which cannot share a process with the unified pubid
# that crawler.rb uses for index-v3 — both define Pubid::Iho::Identifier — so the
# two crawlers run separately, each with its own Gemfile:
#
#   BUNDLE_GEMFILE=Gemfile.legacy bundle exec ruby crawler_legacy.rb
#
# The primary docid and edition are read straight from the data YAML rather than
# via relaton-iho: the data is in the unified lutaml format that legacy
# relaton-iho cannot parse, and only the docid string is needed here.

require 'fileutils'
require 'yaml'
require 'relaton/index'
require 'pubid-iho'

FileUtils.rm Dir.glob('index-v1*') + Dir.glob('index-v2*')

idx_v1 = Relaton::Index.find_or_create :IHO, file: "index-v1.yaml"
# pubid_class makes relaton-index serialize each pubid via #to_h and sort the
# index by document number (matching the original index-v2).
idx_v2 = Relaton::Index.find_or_create :IHO, file: "index-v2.yaml",
                                       pubid_class: ::Pubid::Iho::Identifier

Dir['data/*.yaml'].each do |f|
  data = YAML.safe_load(File.read(f, encoding: "UTF-8"))
  docid = (data['docidentifier'] || []).find { |d| d['primary'] }
  next unless docid

  content = docid['content']
  ed = data['edition']
  ed = ed['content'] if ed.is_a?(Hash)

  id_str = ed ? "#{content} #{ed}" : content
  idx_v1.add_or_update id_str, f

  pubid = Pubid::Iho::Identifier.parse(content)
  pubid.version = ed if ed
  idx_v2.add_or_update pubid, f
rescue StandardError => e
  puts "Error processing #{f}: #{e.message}"
end

idx_v1.save
idx_v2.save
