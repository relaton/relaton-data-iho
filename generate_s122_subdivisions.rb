# frozen_string_literal: true

# One-shot generator: emits per-Appendix YAML records for S-122 1.0.0
# (Marine Protected Area Product Specification), derived from the
# umbrella s-122_1-0-0.yaml. Subdivisions and titles confirmed from
# metanorma-iho#344.

require "yaml"

UMBRELLA = File.join(__dir__, "data/s-122_1-0-0.yaml")

APPENDICES = {
  "A"   => "Data Classification and Encoding Guide",
  "B"   => "Application Schema Documentation",
  "C"   => "Feature Catalogue",
  "D-2" => "GML Data Format Documentation",
  "E"   => "Data Validation Checks",
}.freeze

umbrella = YAML.safe_load_file(UMBRELLA, permitted_classes: [Date])
en_main = umbrella["title"].find { |t| t["language"] == "en" }["content"]

APPENDICES.each do |letter, subtitle|
  record = Marshal.load(Marshal.dump(umbrella))

  slug = "Appendix#{letter.delete('-')}"
  record["id"] = "S122#{slug}"
  record["title"] = [{
    "language" => "en",
    "content"  => "#{en_main}, Appendix #{letter}: #{subtitle}",
    "type"     => "main",
  }]
  record["docidentifier"] = [{
    "content" => "S-122 Appendix #{letter}",
    "type"    => "IHO",
    "primary" => true,
  }]
  record["extent"] = [{
    "locality" => [{
      "type"           => "appendix",
      "reference_from" => letter,
    }],
  }]

  out = File.join(__dir__, "data/s-122appendix#{letter.downcase}_1-0-0.yaml")
  File.write(out, record.to_yaml)
  puts "wrote #{out}"
end
