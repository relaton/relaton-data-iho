# frozen_string_literal: true

# One-shot generator: emits per-Supplement YAML records for S-66 2.0.0
# (Facts about Electronic Charts and Carriage Requirements), derived
# from the umbrella s-66_2-0-0.yaml. Subdivisions and titles confirmed
# from metanorma-iho#344. Attached to edition 2.0.0 only — see plan
# discussion of the two in-force editions.

require "yaml"

UMBRELLA = File.join(__dir__, "data/s-66_2-0-0.yaml")

SUPPLEMENTS = {
  "1" => "ECDIS – Guidance for Good Practice",
  "2" => "International Convention On Standards Of Training, Certification And Watchkeeping For Seafarers (STCW), 1978, As Amended",
  "3" => "Guidance on Chart Datums and the Accuracy of Positions on Charts",
  "4" => "Additional Guidance on Chart Datums and the Accuracy of Positions on Charts",
}.freeze

umbrella = YAML.safe_load_file(UMBRELLA, permitted_classes: [Date])
en_main = umbrella["title"].find { |t| t["language"] == "en" }["content"]

SUPPLEMENTS.each do |number, subtitle|
  record = Marshal.load(Marshal.dump(umbrella))

  record["id"] = "S66Suppl#{number}"
  record["title"] = [{
    "language" => "en",
    "content"  => "#{en_main}, Supplement #{number}: #{subtitle}",
    "type"     => "main",
  }]
  record["docidentifier"] = [{
    "content" => "S-66 Suppl #{number}",
    "type"    => "IHO",
    "primary" => true,
  }]
  record["extent"] = [{
    "locality" => [{
      "type"           => "supplement",
      "reference_from" => number,
    }],
  }]

  out = File.join(__dir__, "data/s-66suppl#{number}_2-0-0.yaml")
  File.write(out, record.to_yaml)
  puts "wrote #{out}"
end
