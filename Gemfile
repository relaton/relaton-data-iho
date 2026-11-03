# frozen_string_literal: true

source "https://rubygems.org"

gem "psych", "~> 5.2.6" # to avoid psych 5.3.0 breaking yaml parsing

# relaton is now a single unpublished gem in the relaton/relaton monorepo. Pull
# it from main (HTTPS so the crawler GH action can clone the public repo
# anonymously, without an SSH key).
gem "relaton", git: "https://github.com/relaton/relaton.git", branch: "main"

# pubid 2.0.5+ is published and carries the IHO component model
# (relaton#440) - the released gem replaces the old metanorma/pubid main
# tracking pin, which made every crawl resolve a different snapshot.
gem "pubid", "~> 2.0.5"
