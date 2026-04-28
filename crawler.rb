# frozen_string_literal: true

require 'relaton/index'
require 'relaton/iho'

FileUtils.rm Dir.glob('index*')

idx_v1 = Relaton::Index.find_or_create :IHO, file: "index-v1.yaml"
idx_v2 = Relaton::Index.find_or_create :IHO, file: "index-v2.yaml",
                                       pubid_class: ::Pubid::Iho::Identifier

Dir['data/*.yaml'].each do |f|
  item = Relaton::Iho::Item.from_yaml File.read(f, encoding: "UTF-8")
  docid = item.docidentifier.find(&:primary)
  ed = item.edition&.content

  id_str = ed ? "#{docid.content} #{ed}" : docid.content
  idx_v1.add_or_update id_str, f

  pubid = docid.pubid
  pubid.version = ed if ed && pubid
  idx_v2.add_or_update pubid, f
rescue StandardError => e
  puts "Error processing #{f}: #{e.message}"
end

idx_v1.save
idx_v2.save
