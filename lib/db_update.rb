# -*- coding: utf-8 -*-

require "yaml"
require "groonga"
require "parallel"
require "./metadata_parser"

require "ap"

def create_db(db_path)
  Groonga::Database.create(:path => db_path)

  Groonga::Schema.create_table("Projects", :type => :hash)
  Groonga::Schema.change_table("Projects") do |table|
    table.uint16("runid")
    table.short_text("study_title")
    table.uint16("taxonid")
    table.uint16("study_type")
    table.short_text("instrument")
    table.text("fulltext")
    table.bool("paper")
  end
  
  Groonga::Schema.create_table("Idx_int", :type => :hash)
  Groonga::Schema.change_table("Idx_int") do |table|
    table.index("Projects.runid")
    table.index("Projects.study_title")
    table.index("Projects.taxonid")
    table.index("Projects.study_type")
    table.index("Projects.instrument")
    table.index("Projects.paper")
  end
  
  Groonga::Schema.create_table("Idx_text",
    type: :patricia_trie,
    key_normalize: true,
    default_tokenizer: "TokenBigram"
  )
  Groonga::Schema.change_table("Idx_text") do |table|
    table.index("Projects.fulltext")
  end
end

def add_record(insert)
  db = Groonga["Projects"]
  studyid = insert[:studyid]
  db.add(studyid)
  
  record = db[studyid]
  record.runid = insert[:runid]
  record.study_title = insert[:study_title]
  record.taxonid = insert[:taxonid]
  record.study_type = insert[:study_type]
  record.instrument = insert[:instrument]
  record.fulltext = insert[:fulltext]
  record.paper = insert[:paper]  
end

if __FILE__ == $0
  config_path = "./config.yaml"
  config = YAML.load_file(config_path)
  #db_path = config["db_path"]
  db_path = "../db_test/project.db"

  Groonga::Context.default_options = { encoding: :utf8 }
  
  case ARGV.first
  when "--up"
    create_db(db_path)
  
  when "--update"
    accessions = config["file_path"]["sra_accessions"]
    studyids = `grep '^.RP' #{accessions} | grep 'live' | grep -v 'control' | cut -f 1 | sort -u`.split("\n")[0..999]
    
    Groonga::Database.open(db_path)
    MetadataParser.load_files(config_path)
    
    ap Groonga["Projects"]

    Groonga::Database.open("../db/idtable.db")
    iddb = Groonga["IDtable"]
    
    ap Groonga["IDtable"]
    
    inserts = Parallel.map(studyids) do |studyid|
      if !Groonga["Projects"][studyid]
        f = MetadataParser.new(studyid, iddb)
        f.insert
      end
    end
    
    Parallel.each(inserts) do |insert|
      add_record(insert) if insert
    end
  
  when "--debug"
    Groonga::Database.open(db_path)
    db = Groonga["Projects"]
    ap db.size
    if ARGV[1]
      ap db.select{|r| r.fulltext =~ /#{ARGV[1]}/ }.map{|r| r.key.key }
    end
  end
end
