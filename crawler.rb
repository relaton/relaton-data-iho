# frozen_string_literal: true

require 'relaton/index'
require 'relaton/iho'

FileUtils.rm Dir.glob('index*')

idx = Relaton::Index.find_or_create :IHO, file: "index-v1.yaml"

Dir['data/*.yaml'].each do |f|
  item = Relaton::Iho::Item.from_yaml File.read(f, encoding: "UTF-8")
  id = item.docidentifier.find(&:primary).content
  ed = item.edition&.content
  id += " #{ed}" if ed
  idx.add_or_update id, f
rescue StandardError => e
  puts "Error processing #{f}: #{e.message}"
end

idx.save
