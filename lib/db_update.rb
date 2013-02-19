# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
require "parallel"

def create_db(db_path)
  Gronnga::Database.create(:path => db_path)
  
  Groonga::Schema.define do |schema|
    schema.create_table("Samples", :type => :hash) do |table|
      table.text("sample_description")
      table.uint16("taxon_id")
      table.short_text("scientific_name")
      table.short_text("submission_id")
    end
    
    schema.create_table("Runs", type: :hash) do |table|
      table.short_text("experiment_id")
      table.short_text("instrument")
      table.short_text("study_id")
      table.short_text("submisssion_id")
      table.reference("sample", "Samples", type: :vector)
    end
    
    schema.create_table("Projects", type: :hash) do |table|
      table.short_text("study_title")
      table.short_text("study_type")
      table.reference("run", "Runs", type: :vector)
      table.short_text("submission_id", type: :vector)
      table.uint16("pubmed_id", type: :vector)
      tbale.uint16("pmc_id", type: :vector)
      table.text("search_fulltext")
    end
    
    schema.create_table("Index_hash", type: :hash) do |table|
      table.index("Samples.taxon_id")
      table.index("Samples.scientific_name")
      table.index("Runs.instrument")
      table.index("Runs.experiment_id")
      table.index("Projects.study_type")
      table.index("Projects.submission_id")
      table.index("Projects.pubmed_id")
      table.index("Projects.pmc_id")
    end
    
    schema.create_table("Index_text",
      type: :patricia_trie,
      key_normalize: true,
      default_tokenizer: "TokenBigram"
    )
    schema.change_table("Index_text") do |table|
      table.index("Projcets.search_fulltext")
    end
  end
end

class DBupdate
  def load_file(config_path)
    config = YAML.load_file(config_path)
    @@accessions = config["sra_accessions"]
    @@run_members = config["sra_run_members"]
    @@xml_base = config["sra_xml_base"]
    @@taxon_table = config["taxon_table"]
    @@pmc_ids = config["PMC-ids"]
    
    publication = config["publication"]
    @@json = open(publication){|f| JSON.load(f) }["ResultSet"]["Result"]
  end
  
  def initialize(id)
    @id = id
  end
  
  def get_xml_path(id, type)
    acc = `grep -m 1 '^#{id}' #{@@accessions} | cut -f 2`.chomp
    acc_head = acc.slice(0..5)
    File.join(@@xml_base, acc_head, acc, acc + ".#{type}.xml")
  end
  
  def sample_insert
    xml = get_xml_path(@id, sample)
    parser = SRAMetadataParser::Sample.new(@id, xml)
    sample_description = parser.sample_description
    taxon_id = parser.taxon_id
    
    scientific_name = `grep #{@@taxon_table} | cut -d ',' -f 2`.chomp
    
    { sample_description: sample_description,
      taxon_id: taxon_id,
      scientific_name: scientific_name }
  end
  
  def run_insert
    experiment_id = `grep -m 1 #{@id} #{@@run_members} | cut -f 2`.chomp    
    xml = get_xml_path(experiment_id, experiment)
    parser = SRAMetadata::Experiment.new(experiment_id, xml)
    instrument = parser.instrument_model
    
    sample = `grep '^#{@id}' #{@@run_members} | cut -f 4 | sort -u`.split("\n")
    
    { experiment_id: experiment_id,
      instrument: instrument,
      sample: sample }
  end
  
  def project_insert
    xml = get_xml_path(@id, study)
    parser = SRAMetadataParser::Study.new(@id, xml)
    study_title = parser.study_title
    study_type = parser.study_type
    
    run = `grep '^#{@id}' #{@@run_members} | cut -f 4 | sort -u`.split("\n")
    
    submission_id = acc
    pubmed_id = @@json.select{|n| n["sra_id"] == acc }.map{|n| n["pmid"] }
    pmc_id_array = pubmed_id.map do |pmid|
      `grep -m 1 #{pmid} #{@@pmc_ids} | cut -d ',' -f 8`.chomp
    end
    pmc_id = pmc_id_array.uniq.compact
    
    fulltext = ":)"
    
    { study_title: study_title,
      study_type: study_type,
      run: run,
      submission_id: submission_id,
      pubmed_id: pubmed_id,
      pmc_id: pmc_id,
      fulltext: fulltext }
  end
end

if __FILE__ == $0
  Groonga::Context.default_options = { encoding: :utf8 }

  config_path = "../config.yaml"
  config = YAML.load_file(config_path)
  db_path = ARGV[1] || config["db_path"]
  
  case ARGV.first
  when "--up"
    create_db(db_path)
  
  when "--update"
    Groonga::Database.open(db_path)
    
    accessions = config["sra_accessions"]
    run_members = config["sra_run_members"]

    studyids = `grep '^.RP' #{accessions} | grep 'live' | grep -v 'control' | cut -f 1`.split("\n")
    
    projects = Groonga["Projects"]
    not_recorded = studyids.select do |studyid|
      !projects[studyid]
    end
    
    # UPDATE SAMPLE
    samples = Groonga["Samples"]
    samples_not_recorded = Parallel.map(not_recorded) do |study_id|
      # studyid => [sampleid, ..]
      `grep #{study_id} #{run_members} | cut -f 4 | sort -u`.split("\n")
    end
    
    Parallel.each(samples_not_recorded.flatten) do |sample_id|
      insert = DBupdate.new(sample_id).sample_insert
      samples.add(sample_id,
                  sample_description: insert[:sample_description],
                  taxon_id: insert[:taxon_id],
                  scientific_name: insert[:scientific_name])
    end
    
    # UPDATE RUN
    runs = Groonga["Runs"]
    runs_not_recorded = Parallel.map(not_recorded) do |study_id|
      # studyid => [runid, ..]
      `grep #{study_id} #{run_members} | cut -f 1 | sort -u`.split("\n")
    end
    
    Parallel.each(runs_not_recorded.flatten) do |run_id|
      insert = DBupdate.new(run_id).run_insert
      runs.add(run_id,
               experiment_id: insert[:experiment_id],
               instrument: insert[:instrument],
               sample: insert[:sample])
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
                   pmc_id: insert[:pmc_id],
                   search_fulltext: insert[:fulltext])
    end
    
  when "--debug"
    require "ap"
    Groonga::Database.open(db_path)
    
    samples = Groonga["Samples"]
    runs = Groonga["Runs"]
    projects = Groonga["Projects"]
    
    query = "genome"
    ap projects.select{|r| r.search_fulltext =~ query }.map{|r| r["_key"] }
    
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
