# frozen_string_literal: true

# Generator for the S-4 layer (relaton-data-iho#55): the 4.10.0 publication
# and part records, one record per section content state, and the relations
# between them.
#
#   bundle exec ruby generate_s4_editions.rb
#
# S-4 is a loose-leaf publication: a Section is the unit that is updated, a
# Part and the publication carry the edition. So every section gets a record
# of its own for each publication edition (S4PartBSection400, edition 4.10.0).
# Its `validity.begins` is when its content came into force (the month of the
# edition that last changed it, when that is 4.9.0 or later), and it `updates` its previous state only when that
# entry belongs to this edition. The edition records keep the changed
# sections as locality-scoped `updates` relations to the previous edition:
# the publication's Record of Updates as bibliographic data.
#
# The section table below is read from the publications' own Records of
# Updates (EN 4.10.0, 4.9.0); the Spanish titles come from the ES 4.9.0
# translation. The French translation of 4.9.0 is not on the IHO site, so no
# French section titles are recorded. These records should eventually be
# derived from the S-4 source's per-section `updates.yaml` (metanorma/iho-s-4)
# instead of this table.

require "date"
require "yaml"

DATA = File.join(__dir__, "data")

EDITIONS = {
  "4.9.0" => {
    previous: "4.8.0",
    pdf: "https://iho.int/uploads/user/pubs/standards/s-4/S4_V4-9-0_March_2021.pdf",
  },
  "4.10.0" => {
    previous: "4.9.0",
    published: "2026-03-01",
    revision_date: "2026-03-01",
    validity: "2026-03-01",
    copyright: "2026",
    language: %w[en],
    pdf: "https://iho.int/uploads/user/pubs/standards/s-4/S-4%20Ed%204.10.0_FINAL.pdf",
  },
}.freeze

PART_TITLES = {
  "A" => "Regulations of the IHO for International (INT) Charts",
  "B" => "Chart Specifications of the IHO for Medium and Large-Scale National and International (INT) Charts",
  "C" => "Chart Specifications of the IHO for Small-Scale International (INT) Charts",
}.freeze

# part => section => { en:, es:, states: { edition => [in-force date, changed in this edition?] } }
SECTIONS = YAML.safe_load_file(File.join(__dir__, "s4_sections.yaml"))

def file_slug(edition) = edition.tr(".", "-")

def load_record(path) = YAML.safe_load_file(path, permitted_classes: [Date])

def write_record(path, record)
  File.write(path, record.to_yaml)
  puts "wrote #{path.sub("#{__dir__}/", "")}"
end

def umbrella_path(edition) = File.join(DATA, "s-4_#{file_slug(edition)}.yaml")
def part_path(part, edition) = File.join(DATA, "s-4part#{part.downcase}_#{file_slug(edition)}.yaml")

def section_path(part, section, edition)
  File.join(DATA, "s-4part#{part.downcase}-section#{section}_#{file_slug(edition)}.yaml")
end

# A relation's item: the IHO docidentifier and the edition it names.
def stub(docid, edition)
  {
    "docidentifier" => [{ "content" => docid, "type" => "IHO", "primary" => true }],
    "edition" => { "content" => edition },
  }
end

def relation(type, docid, edition, stacks = nil)
  rel = { "type" => type, "bibitem" => stub(docid, edition) }
  if stacks
    rel["locality_stack"] = stacks.map do |stack|
      { "locality" => stack.map { |t, ref| { "type" => t, "reference_from" => ref } } }
    end
  end
  rel
end

def section_docid(part, section) = "S-4 Part #{part}, Section #{section}"

def changed_sections(part, edition)
  SECTIONS.fetch(part).select { |_, s| s.dig("states", edition, "changed") }.keys
end

# The 4.10.0 publication record, from the 4.9.0 one with the new edition's
# facts.
def build_umbrella(edition, meta)
  record = load_record(umbrella_path(meta[:previous]))
  record["edition"] = { "content" => edition }
  record["date"] = [{ "type" => "published", "from" => meta[:published] }]
  record["version"] = [{ "revision_date" => meta[:revision_date] }]
  record["validity"] = { "begins" => meta[:validity] }
  record["language"] = meta[:language]
  record["copyright"].each { |c| c["from"] = meta[:copyright] }
  record["source"] = [{ "type" => "pdf", "content" => meta[:pdf] }]
  record
end

def part_record(umbrella, part, edition, pdf)
  record = Marshal.load(Marshal.dump(umbrella))
  record.delete("relation")
  en_main = umbrella["title"].find { |t| t["language"] == "en" }["content"]
  record["id"] = "S4Part#{part}"
  record["title"] = [{ "language" => "en", "content" => "#{en_main} -- Part #{part}: #{PART_TITLES[part]}",
                       "type" => "main" }]
  record["source"] = [{ "type" => "pdf", "content" => pdf }]
  record["docidentifier"] = [{ "content" => "S-4 Part #{part}", "type" => "IHO", "primary" => true }]
  record["extent"] = [{ "locality" => [{ "type" => "part", "reference_from" => part }] }]
  record
end

def section_record(part_rec, part, section, edition, info)
  state = info.fetch("states").fetch(edition)
  record = Marshal.load(Marshal.dump(part_rec))
  record.delete("relation")
  record["id"] = "S4Part#{part}Section#{section}"
  record["title"] = [
    { "language" => "en", "content" => info["en"], "type" => "main" },
    # Only the editions that were translated carry the Spanish title.
    ({ "language" => "es", "content" => info["es"], "type" => "main" } if info["es"] && record["language"]&.include?("es")),
  ].compact
  record["docidentifier"] = [{ "content" => section_docid(part, section), "type" => "IHO", "primary" => true }]
  record["extent"] = [{ "locality" => [
    { "type" => "part", "reference_from" => part },
    { "type" => "section", "reference_from" => section },
  ] }]
  if state["in_force"]
    record["validity"] = { "begins" => state["in_force"] }
  else
    record.delete("validity")
  end
  rels = [relation("partOf", "S-4 Part #{part}", edition)]
  prev = EDITIONS.dig(edition, :previous)
  if state["changed"] && prev
    rels << relation("updates", section_docid(part, section), prev)
  end
  record["relation"] = rels
  record
end

EDITIONS.each do |edition, meta|
  umbrella = File.exist?(umbrella_path(edition)) ? load_record(umbrella_path(edition)) : build_umbrella(edition, meta)
  umbrella.delete("relation")
  prev = meta[:previous]

  parts = PART_TITLES.keys.to_h do |part|
    path = part_path(part, edition)
    rec = File.exist?(path) ? load_record(path) : part_record(umbrella, part, edition, meta[:pdf])
    rec.delete("relation")
    [part, rec]
  end

  # The publication: its parts, and the edition it updates with the
  # sections that changed.
  rels = PART_TITLES.keys.map { |part| relation("hasPart", "S-4 Part #{part}", edition) }
  stacks = PART_TITLES.keys.flat_map do |part|
    changed_sections(part, edition).map { |s| [["part", part], ["section", s]] }
  end
  rels << relation("updates", "S-4", prev, (stacks unless stacks.empty?))
  umbrella["relation"] = rels
  write_record umbrella_path(edition), umbrella

  parts.each do |part, rec|
    rels = [relation("partOf", "S-4", edition)]
    rels += SECTIONS.fetch(part).keys.select { |s| SECTIONS.dig(part, s, "states", edition) }
      .map { |s| relation("hasPart", section_docid(part, s), edition) }
    if File.exist?(part_path(part, prev))
      changed = changed_sections(part, edition).map { |s| [["section", s]] }
      rels << relation("updates", "S-4 Part #{part}", prev, (changed unless changed.empty?))
    end
    rec["relation"] = rels
    write_record part_path(part, edition), rec

    SECTIONS.fetch(part).each do |section, info|
      next unless info.dig("states", edition)

      write_record section_path(part, section, edition), section_record(rec, part, section, edition, info)
    end
  end
end
