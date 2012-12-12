# -*- coding: utf-8 -*-

require "groonga"
require "ap"

if __FILE__ == $0
  # ESTABLISH CONNECTION TO GROONGA DB
  Groonga::Context.default_options = {:encoding => :utf8}
  db = "../db/facet.db"
  Groonga::Database.open(db)
  facets = Groonga["Facets"]
  ap facets.size
  
  if ARGV.first
    query = ARGV.first
    search_result = facets.select{|record| record.fulltext =~ query }
    ap search_result.map{|record| record.key.key }
  end
  
  ap facets["DRP000001"]
end
