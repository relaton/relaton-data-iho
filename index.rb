# frozen_string_literal: true

require 'relaton/index'

idx = Relaton::Index.find_or_create :IHO

Dir['data/*.yaml'].each do |f|
  hash = YAML.load_file(f)
  id = hash.dig('docid', 'id')
  ed = hash.dig('edition', 'content')
  id += " #{ed}" if ed
  idx.add_or_update id, f
end

idx.save
