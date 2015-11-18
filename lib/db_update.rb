# -*- coding: utf-8 -*-

require "groonga"
require "yaml"
require "open-uri"

require "./lib_db_update"

Encoding.default_external = 'utf-8'

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
    
    puts "LOADING TABLES #{Time.now}"
    DBupdate.load_file(config_path)
    
    accessions = config["sra_accessions"]
    run_members = config["sra_run_members"]
    studyids = `awk -F '\t' '$1 ~ /^.RP/ && $3 == "live" && $9 == "public" { print $1 }' #{accessions}`.split("\n")
    
    projects = Groonga["Projects"]
    not_recorded = studyids.select do |studyid|
      !projects[studyid]
    end
    
    puts "UPDATE SAMPLE #{Time.now}"
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
    
    total_sample_number = sample_id_list.size
    sample_processes = []
    sample_id_list.each.with_index do |sample_id, i|
      # wait if process number is > 15
      while sample_processes.select{|th| th.status }.size > 15
        sleep 1
      end
      
      # fork insert process
      pid = fork do
        insert = DBupdate.new(sample_id).sample_insert || Hash.new("")
        samples.add(sample_id,
                    submission_id:      insert[:submission_id],
                    sample_title:       insert[:sample_title],
                    sample_description: insert[:sample_description],
                    taxon_id:           insert[:taxon_id],
                    scientific_name:    insert[:scientific_name])
      end
      
      # create thread to monitor pid
      th = Process.detach(pid)
      sample_processes << th
      
      # progress
      if i % (total_sample_number / 10) == 0
        puts "+10 #{Time.now}"
      end
    end
    Process.waitall
    
    puts "UPDATE RUN #{Time.now}"
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
    
    total_run_number = run_id_list.size
    run_processes = []
    run_id_list.each.with_index do |run_id, i|
      # wait if process number is > 15
      while run_processes.select{|th| th.status }.size > 15
        sleep 1
      end
      
      # fork insert process
      pid = fork do
        insert = DBupdate.new(run_id).run_insert || Hash.new("")
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
      
      # create thread to monitor pid
      th = Process.detach(pid)
      run_processes << th
      
      # progress
      if i % (total_run_number / 10) == 0
        puts "+10 #{Time.now}"
      end
    end
    Process.waitall

    puts "UPDATE PROJECT #{Time.now}"
    study_id_list = not_recorded
    total_study_number = study_id_list.size
    study_processes = []

    study_id_list.each.with_index do |study_id, i|
      # wait if process number is > 15
      while study_processes.select{|th| th.status }.size > 15
        sleep 1
      end
      
      # fork insert process
      pid = fork do
        insert = DBupdate.new(study_id).project_insert || Hash.new("")
        projects.add(study_id,
                     study_title:   insert[:study_title],
                     study_type:    insert[:study_type],
                     run:           insert[:run],
                     submission_id: insert[:submission_id],
                     pubmed_id:     insert[:pubmed_id],
                     pmc_id:        insert[:pmc_id])
      end
      
      # create thread to monitor pid
      th = Process.detach(pid)
      study_processes << th
      
      # progress
      if i % (total_study_number / 10) == 0
        puts "+10 #{Time.now}"
      end
    end
    Process.waitall
    
    puts "UPDATE FULLTEXT SEARCH FIELD #{Time.now}"
    text_not_recorded = projects.map{|r| r["_key"] }.select{|id| !projects[id].search_fulltext }
    
    total_text_number = text_not_recorded.size
    text_processes = []
    text_not_recorded.each.with_index do |study_id, i|
      # wait if process number is > 15
      while text_processes.select{|th| th.status }.size > 15
        sleep 1
      end

      pid = fork do
        insert = []
        record = projects[study_id]
        record[:search_fulltext] = [ 
          record.study_title,
          record.run.map{|r| r.sample }.flatten.map{|r| r ? r.sample_description : "" }.uniq,
          record.run.map{|r| r.experiment_id }.uniq.map{|id| id ? DBupdate.new(id).experiment_description : "" }.uniq,
          DBupdate.new(study_id).project_description ].join("\s")
      end
      
      # create thread to monitor pid
      th = Process.detach(pid)
      text_processes << th
      
      # progress
      if i % (total_text_number / 10) == 0
        puts "+10 #{Time.now}"
      end
    end
    Process.waitall
    
    puts "UPDATE PubMed SEARCH FIELD #{Time.now}"
    pmid_hash = {}
    pmcid_hash = {}
    projects.map{|r| r["_key"] }.each do |study_id|
      record = projects[study_id]
      
      record.pubmed_id.each do |pmid|
        pmid_hash[pmid] ||= []
        pmid_hash[pmid] << study_id
      end
      
      record.pmc_id.each do |pmcid|
        pmcid_hash[pmcid] ||= []
        pmcid_hash[pmcid] << study_id
      end
    end
    
    ## Experimental part: vs eutils connection limit
    # hash for { pmid => [studyid1, studyid2, ..] } or { pmcid => [studyid1, studyid2, ...] }
    def bulk_description(hash, projects)
      num_of_parallel = 100
      while !hash.empty?
        pubid_studyids = Hash.new([])
        id_list = []
        times_loop = num_of_parallel > hash.size ? hash.size : num_of_parallel
        times_loop.times do
          item = hash.shift
          pubid = item[0]
          studyids = item[1]
          
          id_list << item[0]
          pubid_studyids[pubid] = studyids
        end
        DBupdate.new(id_list).bulk_retrieve.each_pair do |id, text|
          studyids = pubid_studyids[id]
          studyids.each do |studyid|
            record = projects[studyid]
            exists = record[:search_fulltext]
            record[:search_fulltext] = [exists, text].join("\s")
          end
        end
      end
    end

    puts "Updating PubMed entries.. #{Time.now}"
    bulk_description(pmid_hash, projects)

    puts "Updating PMC entries.. #{Time.now}"
    bulk_description(pmcid_hash, projects)

    puts "Database Updated. #{Time.now}"

  when "--debug"
    require "ap"
    Groonga::Database.open(db_path)
    
    samples = Groonga["Samples"]
    runs = Groonga["Runs"]
    projects = Groonga["Projects"]
    
    puts "\#sample: " + samples.size.to_s
    puts "\#run: " + runs.size.to_s
    puts "\#project: " + projects.size.to_s
    
    query = "genome"
    hit = projects.select{|r| r.search_fulltext =~ query }
    puts "hit count with query 'genome': " + hit.map{|n| n["_key"] }.size.to_s
    
    def study_summary(gr_object, id)
      r = gr_object[id]
      case id
      when /^.RP/
        { title:      r.study_title,
          study_type: r.study_type,
          sub_id:     r.submission_id,
          pubmed_id:  r.pubmed_id,
          pmc_id:     r.pmc_id,
          run:        r.run,
          text:       r.search_fulltext  }
      when /^.RR/
        { expid:       r.experiment_id,
          strategy:    r.library_strategy,
          source:      r.library_source,
          selection:   r.library_selection,
          layout:      r.library_layout,
          orientation: r.library_orientation,
          instrument:  r.instrument,
          subid:       r.submission_id,
          sample:      r.sample }
      when /^.RS/
        { title:   r.sample_title,
          desc:    r.sample_description,
          taxonid: r.taxon_id,
          sname:   r.scientific_name,
          subid:   r.submission_id }
      end
    end
    ap study_summary(samples, "DRS000001")
    ap study_summary(runs, "DRR000001")
    ap study_summary(projects, "DRP000001")
  end
end
