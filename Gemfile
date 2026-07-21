# frozen_string_literal: true

source "https://rubygems.org"

gem "psych", "~> 5.2.6" # to avoid psych 5.3.0 breaking yaml parsing

# relaton is now a single unpublished gem in the relaton/relaton monorepo. Pull
# it from main (HTTPS so the crawler GH action can clone the public repo
# anonymously, without an SSH key).
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"

# pubid 2.x is unpublished; track the integration branch carrying the IHO
# code->number rename (lossless to_hash/from_hash for the index).
gem "pubid", git: "https://github.com/metanorma/pubid.git", branch: "main"
