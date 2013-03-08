# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
require "parallel"
require "open-uri"

require "./lib_db_update"

require "ap"

if __FILE__ == $0
  Groonga::Context.default_options = { encoding: :utf8 }

  config_path = "../config.yaml"
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
    
    studyids = `grep '^.RP' #{accessions} | grep 'live' | grep -v 'control' | cut -f 1`.split("\n")
    
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
    while !sample_id_list.empty?
      sample_in_progress = sample_id_list.shift(20).select{|id| !samples[id] }
      
      inserts = Parallel.map(sample_in_progress) do |sample_id|
        [sample_id, DBupdate.new(sample_id).sample_insert]
      end
      
      inserts.each do |insert_set|
        sample_id = insert_set[0]
        insert = insert_set[1]
        if insert
          samples.add(sample_id,
                      sample_title: insert[:sample_title],
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
    while !run_id_list.empty?
      run_in_progress = run_id_list.shift(20).select{|id| !runs[id] }
      
      inserts = Parallel.map(run_in_progress) do |run_id|
        [run_id, DBupdate.new(run_id).run_insert]
      end
      
      inserts.each do |insert_set|
        run_id = insert_set[0]
        insert = insert_set[1]
        runs.add(run_id,
                 experiment_id: insert[:experiment_id],
                 instrument: insert[:instrument],
                 library_layout: insert[:library_layout],
                 library_orientation: insert[:library_orientation],
                 library_nominal_length: insert[:library_nominal_length],
                 library_nominal_sdev: insert[:library_nominal_sdev],
                 submission_id: insert[:submission_id],
                 sample: insert[:sample])
      end
    end
    
    # UPDATE PROJECT
    study_id_list = not_recorded
    while !study_id_list.empty?
      study_in_progress = study_id_list.shift(20).select{|id| !projects[id] }
      inserts = Parallel.map(study_in_progress) do |study_id|
        [study_id, DBupdate.new(study_id).project_insert]
      end
      inserts.each do |insert_set|
        study_id = insert_set[0]
        insert = insert_set[1]
        projects.add(study_id,
                     study_title: insert[:study_title],
                     study_type: insert[:study_type],
                     run: insert[:run],
                     submission_id: insert[:submission_id],
                     pubmed_id: insert[:pubmed_id],
                     pmc_id: insert[:pmc_id])
      end
    end
    
    # UPDATE FULLTEXT SEARCH FIELD
    text_not_recorded = projects.map{|r| r["_key"] }.select{|id| !projects[id].search_fulltext }
    while !text_not_recorded.empty?
      study_in_progress = text_not_recorded.shift(20)
      
      inserts = Parallel.map(study_in_progress) do |study_id|
        insert = []
        record = projects[study_id]

        insert << record.study_title
        
        sample_records = record.run.map{|r| r.sample }.flatten
        insert << sample_records.compact.map{|r| r.sample_description }.uniq
        
        experiment_ids = record.run.map{|r| r.experiment_id }.uniq
        insert << experiment_ids.compact.map{|id| DBupdate.new(id).experiment_description }
        
        insert << DBupdate.new(study_id).project_description
        insert << record.pubmed_id.map{|pmid| DBupdate.new(pmid).pubmed_description }
        insert << record.pmc_id.map{|pmcid| DBupdate.new(pmcid).pmc_description }
        
        [study_id, insert.flatten.compact.join("\s")]
      end
      
      inserts.each do |insert_set|
        study_id = insert_set[0]
        full_text = insert_set[1]
        
        record = projects[study_id]
        record[:search_fulltext] = full_text
      end
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
