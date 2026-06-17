# frozen_string_literal: true

source "https://rubygems.org"

gem "psych", "~> 5.2.6" # to avoid psych 5.3.0 breaking yaml parsing

# relaton-iho lives in the relaton/relaton monorepo. Pull it and its unpublished
# 2.2.x sibling gems from main (HTTPS so the crawler GH action can clone the
# public repo anonymously, without an SSH key).
git "https://github.com/relaton/relaton.git", branch: "main", glob: "gems/*/*.gemspec" do
  gem "relaton-iho"
  gem "relaton-bib"
  gem "relaton-core"
  gem "relaton-index"
  gem "relaton-logger"
end

# pubid 2.x is unpublished; track the integration branch carrying the IHO
# code->number rename (lossless to_hash/from_hash for the index).
gem "pubid", git: "https://github.com/metanorma/pubid.git", branch: "rt-new-lutaml-model"
