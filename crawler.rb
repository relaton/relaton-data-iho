# frozen_string_literal: true
#
# Crawler entry point (the relaton/support workflow runs `bundle exec ruby
# crawler.rb`, then zips index*.yaml and commits).
#
# Generates index-v3 — the pubid#to_hash index — in-process with the unified
# pubid (pubid v2), then runs crawler_legacy.rb in a SEPARATE process for the
# legacy index-v1 (string index) and index-v2 (flat pubid-iho hash). pubid-iho
# (pubid v1) defines the same Pubid::Iho::Identifier constant as the unified
# pubid and cannot share a process with it, so it runs under Gemfile.legacy.

require 'bundler'
require 'relaton/index'
require 'relaton/iho'

FileUtils.rm Dir.glob('index-v3*')

# pubid_class is the model class Identifier
# Relaton::Index serializes a row only when `id.is_a?(pubid_class)` and
# reconstructs it via `pubid_class.from_hash`.
idx_v3 = Relaton::Index.find_or_create :IHO, file: "index-v3.yaml",
                                       pubid_class: ::Pubid::Iho::Identifier

# The independently-publishable components whose records carry their own
# edition (mirrors Pubid::Iho::Builder::COMPONENT_EDITIONS).
COMPONENT_EDITION_SLOTS = {
  part: :part_edition,
  supplement: :supplement_edition,
  annex: :annex_edition,
  appendix: :appendix_edition,
  volume: :volume_edition,
}.freeze

def crawler_component_edition_slot(pubid)
  COMPONENT_EDITION_SLOTS.find { |component, _| pubid.public_send(component) }&.last
end

Dir['data/*.yaml'].each do |f|
  item = Relaton::Iho::Item.from_yaml File.read(f, encoding: "UTF-8")
  docid = item.docidentifier.find(&:primary)
  ed = item.edition&.content

  pubid = docid.pubid
  # pubid 2.0.5 (the #440 component model) renamed `version` to `edition`;
  # the old setter raises NoMethodError and the rescue silently skipped
  # every edition-bearing row from index-v3 (relaton#440).
  #
  # The edition slot follows the record's publication mode: a component
  # record (S-100 Part 5, S-66 Suppl 1) is separately published, so its
  # edition lands on the component's own edition attribute — the same
  # slot parsing the printed form ("S-100 Part 5 5.2.0") produces, which
  # is what consumer matching compares against (pubid#440 ruling: a
  # component published separately carries its own edition). Only a
  # component-less record takes the base edition.
  if ed && pubid
    slot = crawler_component_edition_slot(pubid)
    slot ? pubid.public_send(:"#{slot}=", ed) : pubid.edition = ed
  end
  idx_v3.add_or_update pubid, f
rescue StandardError => e
  puts "Error processing #{f}: #{e.message}"
end

idx_v3.save

# index-v1 + index-v2 via the legacy pubid-iho stack, in a separate process
# (unbundled so it resolves Gemfile.legacy, not this crawler's bundle).
legacy_gemfile = File.expand_path("Gemfile.legacy", __dir__)
legacy_crawler = File.expand_path("crawler_legacy.rb", __dir__)
Bundler.with_unbundled_env do
  env = { "BUNDLE_GEMFILE" => legacy_gemfile }
  system(env, "bundle", "install", "--quiet") || abort("legacy bundle install failed")
  system(env, "bundle", "exec", "ruby", legacy_crawler) || abort("crawler_legacy.rb failed")
end
