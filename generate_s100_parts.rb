# frozen_string_literal: true

# One-shot generator: emits per-part YAML records for S-100 5.2.0
# under data/, derived from the umbrella s-100_5-2-0.yaml plus the
# metanorma/iho-s-100 collection.yml part list.
#
# Annex A is skipped: pubid-iho's parser has no `Annex` rule yet, so a
# docidentifier "S-100 Annex A" would fail Pubid::Iho::Identifier.parse
# at load time and break the crawler.

require "yaml"

UMBRELLA = File.join(__dir__, "data/s-100_5-2-0.yaml")

# id-suffix => part-subtitle (titles taken from
# metanorma/iho-s-100/sources/<part>/document.adoc :title-part:)
PARTS = {
  "0"   => "Overview",
  "1"   => "Conceptual Schema Language",
  "2"   => "Management of Registers",
  "2a"  => "Concept and Data Dictionary Registers",
  "2b"  => "Portrayal Register",
  "3"   => "General Feature Model and Rules for Application Schema",
  "4a"  => "Metadata",
  "4b"  => "Metadata for Imagery and Gridded Data",
  "4c"  => "Metadata - Data Quality",
  "5"   => "Feature Catalogue",
  "6"   => "Coordinate Reference Systems",
  "7"   => "Spatial Schema",
  "8"   => "Imagery and Gridded Data",
  "9"   => "Portrayal",
  "9a"  => "Portrayal (Lua)",
  "10a" => "ISO/IEC 8211 Encoding",
  "10b" => "GML Data Format",
  "10c" => "HDF5 Data Model and File Format",
  "11"  => "Product Specifications",
  "12"  => "S-100 Maintenance Procedures",
  "13"  => "Scripting",
  "14"  => "Online Data Exchange",
  "15"  => "Data Protection Scheme",
  "16"  => "Interoperability Catalogue Model",
  "16a" => "Harmonised Portrayal of S-100 Products",
  "17"  => "Discovery Metadata for Information Exchange Catalogues",
  "18"  => "Language Packs",
}.freeze

umbrella = YAML.safe_load_file(UMBRELLA, permitted_classes: [Date])
en_main = umbrella["title"].find { |t| t["language"] == "en" }["content"]

PARTS.each do |part, subtitle|
  record = Marshal.load(Marshal.dump(umbrella))

  record["id"] = "S100Part#{part}"
  record["title"] = [{
    "language" => "en",
    "content"  => "#{en_main} -- Part #{part}: #{subtitle}",
    "type"     => "main",
  }]
  record["docidentifier"] = [{
    "content" => "S-100 Part #{part}",
    "type"    => "IHO",
    "primary" => true,
  }]
  record["extent"] = [{
    "locality" => [{
      "type"           => "part",
      "reference_from" => part,
    }],
  }]

  out = File.join(__dir__, "data/s-100part#{part}_5-2-0.yaml")
  File.write(out, record.to_yaml)
  puts "wrote #{out}"
end
