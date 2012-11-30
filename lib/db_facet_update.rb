# -*- coding: utf-8 -*-

require "yaml"
require "groonga"
require "parallel"

def create_facet_db(db_path)
  Groonga::Database.create(:path => db_path)

  Groonga::Schema.create_table("Facets", :type => :hash)
  Groonga::Schema.change_table("Facets") do |table|
    table.shorttext("studyid")
    table.uint16("taxonid")
    table.uint16("study_type")
    table.shorttext("instrument")
    table.text("fulltext")
  end
  
  Groonga::Schema.create_table("Idx_int", :type => :hash)
  Groonga::Schema.change_table("Idx_int") do |table|
    table.index("Facets.studyid")
    table.index("Facets.taxonid")
    table.index("Facets.study_type")
    table.index("Facets.instrument")
  end
  
  Groonga::Schema.create_table("Idx_text",
    type: :patricia_trie,
    key_normalize: true,
    default_tokenizer: "TokenBigram"
  )
  Groonga::Schema.change_table("Idx_text") do |table|
    table.index("Facets.fulltext")
  end
end

def add_record(insert)
  facets = Groonga["Facets"]
  runid = insert[:runid]
  facets.add(runid)
  
  record = facets[runid]
  record.studyid = insert[:studyid]
  record.taxonid = insert[:taxonid]
  record.study_type = insert[:study_type]
  record.instrument = insert[:instrument]
  record.fulltext = insert[:full_text]
rescue
  retry   
end

if __FILE__ == $0
  config = YAML.load_file("./config.yaml")
  db_path = config["facet"]["db_path"]

  Groonga::Context.default_option = { encoding: :utf8 }
  case ARGV.first
  when "--up"
    create_facet_db(db_path)
  
  when "--connect"
    Groonga::Database.open(db)
  
  end
end
