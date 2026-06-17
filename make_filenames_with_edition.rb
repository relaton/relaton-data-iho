# frozen_string_literal: true

require 'relaton/index'

idx = Relaton::Index.find_or_create :IHO

# Dir['data/*.yaml'].each do |f|
#   hash = YAML.load_file(f)
#   ed = hash.dig('edition', 'content')
#   next unless ed

#   id = hash.dig('docid', 'id')
#   filename = "#{id.downcase}_#{ed.gsub('.', '-')}.yaml"
#   idx.add_or_update id, filename
# end

idx.instance_variable_get(:@index).each do |v|
  old_file = v[:file]
  dir = File.dirname(old_file)
  new_file = "#{dir}/#{v[:id].gsub(' ', '_').gsub(%r{[/.]}, '-').downcase}.yaml"
  next if old_file == new_file

  v[:file] = new_file
  FileUtils.mv old_file, new_file
rescue Errno::ENOENT => e
  raise e
end

idx.save
