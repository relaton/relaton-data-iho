# frozen_string_literal: true

# One-shot generator: emits the per-annex YAML record for S-100 5.2.0
# Annex A "Terms and Definitions". Sourced from
# metanorma/iho-s-100/sources/annex-a/document.adoc.

require "yaml"

UMBRELLA = File.join(__dir__, "data/s-100_5-2-0.yaml")

ANNEXES = {
  "A" => "Terms and Definitions",
}.freeze

umbrella = YAML.safe_load_file(UMBRELLA, permitted_classes: [Date])
en_main = umbrella["title"].find { |t| t["language"] == "en" }["content"]

ANNEXES.each do |letter, subtitle|
  record = Marshal.load(Marshal.dump(umbrella))

  record["id"] = "S100Annex#{letter}"
  record["title"] = [{
    "language" => "en",
    "content"  => "#{en_main} -- Annex #{letter}: #{subtitle}",
    "type"     => "main",
  }]
  record["docidentifier"] = [{
    "content" => "S-100 Annex #{letter}",
    "type"    => "IHO",
    "primary" => true,
  }]
  record["extent"] = [{
    "locality" => [{
      "type"           => "annex",
      "reference_from" => letter,
    }],
  }]

  out = File.join(__dir__, "data/s-100annex#{letter.downcase}_5-2-0.yaml")
  File.write(out, record.to_yaml)
  puts "wrote #{out}"
end
