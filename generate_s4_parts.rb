# frozen_string_literal: true

# One-shot generator: emits per-part YAML records for S-4 4.9.0 under
# data/, derived from the umbrella s-4_4-9-0.yaml. Part list confirmed by
# @ronaldtse and titles taken from the IHO PDF cover (page 3):
# https://iho.int/uploads/user/pubs/standards/s-4/S4_V4-9-0_March_2021.pdf

require "yaml"

UMBRELLA = File.join(__dir__, "data/s-4_4-9-0.yaml")
PDF_URL = "https://iho.int/uploads/user/pubs/standards/s-4/S4_V4-9-0_March_2021.pdf"

PARTS = {
  "A" => "Regulations of the IHO for International (INT) Charts",
  "B" => "Chart Specifications of the IHO for Medium and Large-Scale National and International (INT) Charts",
  "C" => "Chart Specifications of the IHO for Small-Scale International (INT) Charts",
}.freeze

umbrella = YAML.safe_load_file(UMBRELLA, permitted_classes: [Date])
en_main = umbrella["title"].find { |t| t["language"] == "en" }["content"]

PARTS.each do |part, subtitle|
  record = Marshal.load(Marshal.dump(umbrella))

  record["id"] = "S4Part#{part}"
  record["title"] = [{
    "language" => "en",
    "content"  => "#{en_main} -- Part #{part}: #{subtitle}",
    "type"     => "main",
  }]
  record["source"] = [{ "type" => "pdf", "content" => PDF_URL }]
  record["docidentifier"] = [{
    "content" => "S-4 Part #{part}",
    "type"    => "IHO",
    "primary" => true,
  }]
  record["extent"] = [{
    "locality" => [{
      "type"           => "part",
      "reference_from" => part,
    }],
  }]

  out = File.join(__dir__, "data/s-4part#{part.downcase}_4-9-0.yaml")
  File.write(out, record.to_yaml)
  puts "wrote #{out}"
end
