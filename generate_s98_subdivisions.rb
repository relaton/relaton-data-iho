# frozen_string_literal: true

# One-shot generator: emits per-Part and per-Annex YAML records for S-98
# 1.0.0, derived from the umbrella s-98_1-0-0.yaml. Subdivisions and
# titles confirmed from metanorma-iho#344 (the table images of the
# S-100-family publications). The "(Informative)" qualifier is part of
# the official IHO title for Annexes A and B.

require "yaml"

UMBRELLA = File.join(__dir__, "data/s-98_1-0-0.yaml")

PARTS = {
  "A" => "Level 1 Interoperability",
  "B" => "Level 2 Interoperability",
  "C" => "Level 3 Interoperability",
  "D" => "Level 4 Interoperability",
}.freeze

ANNEXES = {
  "A" => "(Informative) Operational Contexts, Scenarios and Use Cases",
  "B" => "(Informative) Validation Checks",
  "C" => "Harmonised User Experience for ECDIS and INS",
}.freeze

umbrella = YAML.safe_load_file(UMBRELLA, permitted_classes: [Date])
en_main = umbrella["title"].find { |t| t["language"] == "en" }["content"]

PARTS.each do |letter, subtitle|
  record = Marshal.load(Marshal.dump(umbrella))

  record["id"] = "S98Part#{letter}"
  record["title"] = [{
    "language" => "en",
    "content"  => "#{en_main}, Part #{letter}: #{subtitle}",
    "type"     => "main",
  }]
  record["docidentifier"] = [{
    "content" => "S-98 Part #{letter}",
    "type"    => "IHO",
    "primary" => true,
  }]
  record["extent"] = [{
    "locality" => [{
      "type"           => "part",
      "reference_from" => letter,
    }],
  }]

  out = File.join(__dir__, "data/s-98part#{letter.downcase}_1-0-0.yaml")
  File.write(out, record.to_yaml)
  puts "wrote #{out}"
end

ANNEXES.each do |letter, subtitle|
  record = Marshal.load(Marshal.dump(umbrella))

  record["id"] = "S98Annex#{letter}"
  record["title"] = [{
    "language" => "en",
    "content"  => "#{en_main}, Annex #{letter} #{subtitle}",
    "type"     => "main",
  }]
  record["docidentifier"] = [{
    "content" => "S-98 Annex #{letter}",
    "type"    => "IHO",
    "primary" => true,
  }]
  record["extent"] = [{
    "locality" => [{
      "type"           => "annex",
      "reference_from" => letter,
    }],
  }]

  out = File.join(__dir__, "data/s-98annex#{letter.downcase}_1-0-0.yaml")
  File.write(out, record.to_yaml)
  puts "wrote #{out}"
end
