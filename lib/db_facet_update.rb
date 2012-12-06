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
    table.bool("paper")
  end
  
  Groonga::Schema.create_table("Idx_int", :type => :hash)
  Groonga::Schema.change_table("Idx_int") do |table|
    table.index("Facets.studyid")
    table.index("Facets.taxonid")
    table.index("Facets.study_type")
    table.index("Facets.instrument")
    table.index("Facets.paper")
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
  db = Groonga["Facets"]
  runid = insert[:runid]
  db.add(runid)
  
  record = db[runid]
  record.studyid = insert[:studyid]
  record.taxonid = insert[:taxonid]
  record.study_type = insert[:study_type]
  record.instrument = insert[:instrument]
  record.fulltext = insert[:fulltext]
  record.paper = insert[:paper]  
end

if __FILE__ == $0
  config = YAML.load_file("./config.yaml")
  db_path = config["facet"]["db_path"]

  Groonga::Context.default_option = { encoding: :utf8 }
  case ARGV.first
  when "--up"
    create_facet_db(db_path)
  
  when "--connect"
    accessions = ARGV[1]
    runids = `grep '^RR' #{accessions} | grep 'live' | grep -v 'control' | cut -f 1`.split("\n")
    
    inserts = Parallel.map(runids) do |runid|
      f = FacetParser.new(runid)
      f.facets
    end
    
    Groonga::Database.open(db_path)
    Parallel.each(inserts) do |insert|
      add_record(insert)
    end
  end
end
