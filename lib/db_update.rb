# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
require "parallel"
require "open-uri"

require File.expand_path(File.dirname(__FILE__)) + "/lib_db_update"

require "ap"

if __FILE__ == $0
  Groonga::Context.default_options = { encoding: :utf8 }

  #config_path = "../config.yaml"
  config_path = "./config.yaml"
  config = YAML.load_file(config_path)
  db_path = ARGV[1] || config["db_path"]
  
  case ARGV.first
  when "--up"
    DBupdate.create_db(db_path)
  
  when "--update"
    Groonga::Database.open(db_path)
    DBupdate.load_file(config_path)
    
    accessions = config["sra_accessions"]
    run_members = config["sra_run_members"]

    studyids = `grep '^.RP' #{accessions} | grep 'live' | grep -v 'control' | cut -f 1`.split("\n")[0..99]
    
    projects = Groonga["Projects"]
    not_recorded = studyids.select do |studyid|
      !projects[studyid]
    end
    
    # UPDATE SAMPLE
    samples_not_recorded = Parallel.map(not_recorded) do |study_id|
      `grep #{study_id} #{run_members} | cut -f 4 | sort -u`.split("\n")
    end
    sample_id_list = samples_not_recorded.flatten.uniq.select do |id|
      id =~ /^(S|E|D)RS\d{6}$/
    end
    
    samples = Groonga["Samples"]
    Parallel.each(sample_id_list) do |sample_id|
      if !samples[sample_id]
        insert = DBupdate.new(sample_id).sample_insert
        if insert
          samples.add(sample_id,
                      sample_description: insert[:sample_description],
                      taxon_id: insert[:taxon_id],
                      scientific_name: insert[:scientific_name])
        end
      end
    end
    
    # UPDATE RUN
    runs_not_recorded = Parallel.map(not_recorded) do |study_id|
      `grep #{study_id} #{run_members} | cut -f 1 | sort -u`.split("\n")
    end
    run_id_list = runs_not_recorded.flatten.uniq.select do |id|
      id =~ /^(S|E|D)RR\d{6}$/
    end
    
    runs = Groonga["Runs"]
    Parallel.each(run_id_list) do |run_id|
      if !runs[run_id]
        insert = DBupdate.new(run_id).run_insert
        runs.add(run_id,
                 experiment_id: insert[:experiment_id],
                 instrument: insert[:instrument],
                 library_layout: insert[:library_layout],
                 submission_id: insert[:submission_id],
                 sample: insert[:sample])
      end
    end
    
    # UPDATE PROJECT
    Parallel.each(not_recorded) do |study_id|
      insert = DBupdate.new(study_id).project_insert
      projects.add(study_id,
                   study_title: insert[:study_title],
                   study_type: insert[:study_type],
                   run: insert[:run],
                   submission_id: insert[:submission_id],
                   pubmed_id: insert[:pubmed_id],
                   pmc_id: insert[:pmc_id])
    end
    
    # UPDATE FULLTEXT SEARCH FIELD
    Parallel.each(not_recorded) do |study_id|
      insert = []
      
      record = projects[study_id]
      insert << record.study_title
      
      sample_records = record.run.map{|r| r.sample }.flatten.uniq
      insert << sample_records.map{|r| r.sample_description }.uniq
      
      experiment_ids = record.run.map{|r| r.experiment_id }.uniq
      insert << experiment_ids.map{|id| DBupdate.new(id).experiment_description }
      
      insert << DBupdate.new(study_id).project_description
      insert << record.pubmed_id.map{|pmid| DBupdate.new(pmid).pubmed_description }
      insert << record.pmc_id.map{|pmcid| DBupdate.new(pmcid).pmc_description }
      
      record[:search_fulltext] = insert.flatten.join("\s")
    end
    
  when "--debug"
    require "ap"
    Groonga::Database.open(db_path)
    
    samples = Groonga["Samples"]
    runs = Groonga["Runs"]
    projects = Groonga["Projects"]
    
    query = "genome"
    hit = projects.select{|r| r.search_fulltext =~ query }
    ap hit.map{|n| n["_key"] }
    
    ap projects["ERP000230"].submission_id
    
    ap samples.size
    ap runs.size
    ap projects.size
  end
end

=begin
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
    table.short_text("scientific_name")
    table.uint16("study_type")
    table.short_text("instrument")
    table.text("fulltext")
    table.bool("paper")
  end
  
  Groonga::Schema.create_table("Idx_int", :type => :hash)
  Groonga::Schema.change_table("Idx_int") do |table|
    table.index("Projects.runid")
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
    table.index("Projects.study_title")
    table.index("Projects.scientific_name")
    table.index("Projects.fulltext")
  end
end

def add_record(db, insert)
  studyid = insert[:studyid]
  db.add(studyid)
  
  record = db[studyid]
  record.runid = insert[:runid]
  record.study_title = insert[:study_title]
  record.taxonid = insert[:taxonid]
  record.scientific_name = insert[:scientific_name]
  record.study_type = insert[:study_type]
  record.instrument = insert[:instrument]
  record.fulltext = insert[:fulltext]
  record.paper = insert[:paper]
end

if __FILE__ == $0
  config_path = "../config.yaml"
  config = YAML.load_file(config_path)
  #db_path = config["project_db_path"]
  db_path = "../db_test/project.db"

  Groonga::Context.default_options = { encoding: :utf8 }
  
  case ARGV.first
  when "--up"
    create_db(db_path)
  
  when "--update"
    accessions = config["file_path"]["sra_accessions"]
    studyids = `grep '^.RP' #{accessions} | grep 'live' | grep -v 'control' | cut -f 1 | sort -u`.split("\n")
    
    project_db = Groonga::Database.open(db_path)
    db = Groonga["Projects"]
    not_recorded = studyids.select do |studyid|
      !db[studyid]
    end
    
    wlist = not_recorded.delete_if{|id| id =~ /^(ERP000238|SRP001518|SRP002163|SRP011970)$/ }
    
    while !wlist.empty?
      list_of_id = wlist.shift(10)
      MetadataParser.load_files(config_path)
      inserts = Parallel.map(list_of_id) do |studyid|
        begin
          f = MetadataParser.new(studyid)
          f.insert
        rescue => e
          puts studyid
          puts e
        end
      end
      
      if project_db.closed?
        project_db = Groonga::Database.open(db_path)
      end
      db = Groonga["Projects"]
      
      Parallel.each(inserts.compact) do |insert|
        add_record(db, insert)
      end
      puts list_of_id
      puts "done. #{Time.now}"
    end
  
  when "--debug"
    Groonga::Database.open(db_path)
    db = Groonga["Projects"]
    ap db.size
    if ARGV[1]
      ap db.select{|r| r.fulltext =~ ARGV[1] }.map{|r| r.key.key }
    end
  end
end
=end
