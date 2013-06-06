# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
require "parallel"
require "open-uri"

require "./lib_db_update"

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
    
    studyids = `awk -F '\t' '$1 ~ /^.RP/ && $3 == "live" && $9 == "public" { print $1 }' #{accessions}`.split("\n")
    
    projects = Groonga["Projects"]
    not_recorded = studyids.select do |studyid|
      !projects[studyid]
    end
    
    # UPDATE SAMPLE
    study_sample_hash = {}
    study_sample_raw = `awk -F '\t' '{ print $5 "\t" $4 }' #{run_members}`
    study_sample_raw.split("\n").each do |line|
      st_sa = line.split("\t")
      study_sample_hash[st_sa[0]] ||= []
      study_sample_hash[st_sa[0]] << st_sa[1]
    end
    
    samples_not_recorded = not_recorded.map{|study_id| study_sample_hash[study_id] }
    sample_id_list = samples_not_recorded.flatten.uniq.select do |id|
      id =~ /^(S|E|D)RS\d{6}$/
    end
    
    processing_samples = sample_id_list.size.to_s
    sample_n = 0
    samples = Groonga["Samples"]
    while !sample_id_list.empty?
      sample_in_progress = sample_id_list.shift(100).select{|id| !samples[id] }
      
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
      sample_n += 100
      puts "#{Time.now}\t#{sample_n.to_s}/#{processing_samples}"
    end
    
    # UPDATE RUN
    study_run_hash = {}
    study_run_raw = `awk -F '\t' '{ print $5 "\t" $1 }' #{run_members}`
    study_run_raw.split("\n").each do |line|
      st_ru = line.split("\t")
      study_run_hash[st_ru[0]] ||= []
      study_run_hash[st_ru[0]] << st_ru[1]
    end
    
    runs_not_recorded = not_recorded.map{|study_id| study_run_hash[study_id] }
    run_id_list = runs_not_recorded.flatten.uniq.select do |id|
      id =~ /^(S|E|D)RR\d{6}$/
    end
    
    processing_run = run_id_list.size.to_s
    run_n = 0
    runs = Groonga["Runs"]
    while !run_id_list.empty?
      run_in_progress = run_id_list.shift(100).select{|id| !runs[id] }
      
      inserts = Parallel.map(run_in_progress) do |run_id|
        [run_id, DBupdate.new(run_id).run_insert]
      end
      
      inserts.each do |insert_set|
        run_id = insert_set[0]
        insert = insert_set[1]
        runs.add(run_id,
                 experiment_id: insert[:experiment_id],
                 instrument: insert[:instrument],
                 library_strategy: insert[:library_strategy],
                 library_source: insert[:library_source],
                 library_selection: insert[:library_selection],
                 library_layout: insert[:library_layout],
                 library_orientation: insert[:library_orientation],
                 library_nominal_length: insert[:library_nominal_length],
                 library_nominal_sdev: insert[:library_nominal_sdev],
                 submission_id: insert[:submission_id],
                 sample: insert[:sample])
      end
      run_n += 100
      puts "#{Time.now}\t#{run_n.to_s}/#{processing_run}"
    end
    
    # UPDATE PROJECT
    study_id_list = not_recorded
    processing_study = not_recorded.size.to_s
    study_n = 0
    while !study_id_list.empty?
      study_in_progress = study_id_list.shift(100).select{|id| !projects[id] }
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
      study_n += 100
      puts "#{Time.now}\t#{study_n.to_s}/#{processing_study}"
    end
    
    # UPDATE FULLTEXT SEARCH FIELD
    text_not_recorded = projects.map{|r| r["_key"] }.select{|id| !projects[id].search_fulltext }
    processing_text = text_not_recorded.size.to_s
    text_n = 0
    while !text_not_recorded.empty?
      study_in_progress = text_not_recorded.shift(100)
      
      insert_meta = Parallel.map(study_in_progress) do |study_id|
        insert = []
        record = projects[study_id]
        
        insert << record.study_title
        
        sample_records = record.run.map{|r| r.sample }.flatten
        insert << sample_records.compact.map{|r| r.sample_description }.uniq
        
        experiment_ids = record.run.map{|r| r.experiment_id }.uniq
        insert << experiment_ids.compact.map{|id| DBupdate.new(id).experiment_description }
        
        insert << DBupdate.new(study_id).project_description
        
        [study_id, insert.flatten.compact.join("\s")]
      end
      
      insert_pubmed = {}
      study_in_progress.each do |study_id|
        insert_pubmed[study_id] ||= []
        record = projects[study_id]
        insert_pubmed[study_id] << record.pubmed_id.map{|pmid| DBupdate.new(pmid).pubmed_description }
        insert_pubmed[study_id] << record.pmc_id.map{|pmcid| DBupdate.new(pmcid).pmc_description }
      end
      
      insert_meta.each do |insert_set|
        study_id = insert_set[0]
        full_text = insert_set[1]
        pubmed_text = insert_pubmed[study_id].flatten.compact.join("\s")
        
        record = projects[study_id]
        record[:search_fulltext] = [full_text, pubmed_text].join("\s")
      end
      text_n += 100
      puts "#{Time.now}\t#{text_n.to_s}/#{processing_text}"
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
    
    #ap projects["ERP000230"].submission_id
    
    ap samples.size
    ap runs.size
    ap projects.size
  end
end
