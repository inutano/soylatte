# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
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
    
    ### UPDATE SAMPLE
    study_sample_hash = {}
    study_sample_raw = `awk -F '\t' '{ print $5 "\t" $4 }' #{run_members}`
    study_sample_raw.split("\n").each do |line|
      st_sa = line.split("\t")
      study_sample_hash[st_sa[0]] ||= []
      study_sample_hash[st_sa[0]] << st_sa[1]
    end
    
    samples = Groonga["Samples"]
    samples_not_recorded = not_recorded.map{|study_id| study_sample_hash[study_id] }
    sample_id_list = samples_not_recorded.flatten.uniq.select do |id|
      id =~ /^(S|E|D)RS\d{6}$/ && !samples[id]
    end
    
    sample_threads = sample_id_list.lazy.map do |sample_id|
      Thread.new do
        insert = DBupdate.new(sample_id).sample_insert
        if insert
          begin
            samples.add(sample_id,
                        sample_title: insert[:sample_title],
                        sample_description: insert[:sample_description],
                        taxon_id: insert[:taxon_id],
                        scientific_name: insert[:scientific_name])
          rescue TypeError
          end
        end
      end
    end
    
    sample_n = 0
    num_blocks = 4
    sample_threads.each_slice(num_blocks).each do |group|
      group.each{|t| t.join ; Thread.kill(t) }
      sample_n += num_blocks
      puts "#{Time.now}\t#{sample_n}/#{sample_id_list.size}" if sample_n % 10 == 0
    end
    
    # UPDATE RUN
    study_run_hash = {}
    study_run_raw = `awk -F '\t' '{ print $5 "\t" $1 }' #{run_members}`
    study_run_raw.split("\n").each do |line|
      st_ru = line.split("\t")
      study_run_hash[st_ru[0]] ||= []
      study_run_hash[st_ru[0]] << st_ru[1]
    end
    
    runs = Groonga["Runs"]
    runs_not_recorded = not_recorded.map{|study_id| study_run_hash[study_id] }
    run_id_list = runs_not_recorded.flatten.uniq.select do |id|
      id =~ /^(S|E|D)RR\d{6}$/ && !runs[id]
    end
    
    run_threads = run_id_list.lazy.map do |run_id|
      Thread.new do
        insert = DBupdate.new(run_id).run_insert
        if insert
          begin
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
          rescue TypeError
          end
        end
      end
    end
    
    run_n = 0
    num_blocks = 4
    run_threads.each_slice(num_blocks).each do |group|
      group.each{|t| t.join ; Thread.kill(t) }
      run_n += num_blocks
      puts "#{Time.now}\t#{run_n}/#{run_id_list.size}" if run_n % 10 == 0
    end
    
    # UPDATE PROJECT
    study_id_list = not_recorded
    study_threads = study_id_list.lazy.map do |study_id|
      Thread.new do
        insert = DBupdate.new(study_id).project_insert
        if insert
          begin
            projects.add(study_id,
                         study_title: insert[:study_title],
                         study_type: insert[:study_type],
                         run: insert[:run],
                         submission_id: insert[:submission_id],
                         pubmed_id: insert[:pubmed_id],
                         pmc_id: insert[:pmc_id])
          rescue TypeError
          end
        end
      end
    end
    
    study_n = 0
    num_blocks = 4
    study_threads.each_slice(num_blocks).each do |group|
      group.each{|t| t.join ; Thread.kill(t) }
      study_n += num_blocks
      puts "#{Time.now}\t#{study_n}/#{study_id_list.size}" if study_n % 10 == 0
    end
    
    # UPDATE FULLTEXT SEARCH FIELD
    text_not_recorded = projects.map{|r| r["_key"] }.select{|id| !projects[id].search_fulltext }
    
    text_threads = text_not_recorded.lazy.map do |study_id|
      Thread.new do
        begin
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
        
        record[:search_fulltext] = insert.join("\s")
        rescue TypeError
        end
      end
    end
    
    text_n = 0
    num_blocks = 4
    text_threads.each_slice(num_blocks).each do |group|
      group.each{|t| t.join ; Thread.kill(t) }
      text_n += num_blocks
      puts "#{Time.now}\t#{text_n}/#{text_not_recorded.size}" if text_n % 10 == 0
    end
    
    
    pmid_hash = {}
    pmcid_hash = {}
    text_not_recorded.each do |study_id|
      record = projects[study_id]
      pmid = record.pubmed_id
      pmcid = record.pmc_id
      
      pmid_hash[pmid] ||= []
      pmid_hash[pmid] << study_id
      
      pmcid_hash[pmcid] ||= []
      pmcid_hash[pmcid] << study_id
    end
    
    pmid_hash.each_pair do |pmid, studyid_list|
      pubmed_desc = DBupdate.new(pmcid).pmc_description
      if pubmed_desc
        studyid_list.each do |study_id|
          record = projects[study_id]
          text = record[:search_fulltext]
          record[:search_fulltext] = text + pubmed_desc
        end
      end
    end
    
    pmcid_hash.each_pair do |pmcid, studyid_list|
      pmc_desc = DBupdate.new(pmcid).pmc_description
      if pmc_desc
        studyid_list.each do |study_id|
          record = projects[study_id]
          text = record[:search_fulltext]
          record[:search_fulltext] = text + pmc_desc
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
    
    #ap projects["ERP000230"].submission_id
    
    ap samples.map{|n| n["_key"] }
    
    ap samples.size
    ap runs.size
    ap projects.size
  end
end
