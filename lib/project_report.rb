# -*- coding: utf-8 -*-

require "yaml"
require "open-uri"
require "json"
require File.expand_path(File.dirname(__FILE__)) + "/sra_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pubmed_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pmc_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/fastqc_result_parser"

class ProjectReport
  def self.load_files(config_path)
    config = YAML.load_file(config_path)
    fpath = config["file_path"]
    @@xmlbase = fpath["xmlbase"]
    @@accessions = fpath["sra_accessions"]
    @@run_members = fpath["sra_run_members"]
    @@taxon_table = fpath["taxon_table"]
    @@fqc_path = config["fqc_path"]

    @@eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?"

    raw_json = open(fpath["publication"]).read
    @@paper_json = JSON.parse(raw_json, :symbolize_names => true)

    @@pmcid_table = fpath["PMC-ids"]
  end
  
  def initialize(studyid)
    @studyid = studyid
    @subid = `grep "^#{@studyid}" #{@@accessions} | cut -f 2`.chomp
    @xml_head = File.join(@@xmlbase, @subid.slice(0..5), @subid, @subid)

    @paperinfo = @@paper_json[:ResultSet][:Result].select{|ent| ent[:sra_id] == @subid }
  end
  attr_reader :subid
  
  def study
    prsr = SRAMetadataParser::Study.new(@studyid, @xml_head + ".study.xml")
    { study_title: prsr.study_title,
      study_type: prsr.study_type }
  end
  
  def sample
    sampleid_array = `grep #{@studyid} #{@@run_members} | cut -f 4`.split("\n")
    sample_table = sampleid_array.uniq.map do |sampleid|
      prsr = SRAMetadataParser::Sample.new(sampleid, @xml_head + ".sample.xml")
      if prsr
        taxonid = prsr.taxon_id
        field = `cat #{@@taxon_table} | awk -F "|" '$1 == #{taxonid} && $4 ~ "scientific" { print $2 }'`
        scientific_name = field.chomp.delete("\t")
        { sampleid: sampleid,
          sample_description: prsr.sample_description,
          taxonid: taxonid,
          scientific_name: scientific_name }
      end
    end
    sample_table.compact
  end
  
  def experiment
    expid_array = `grep #{@studyid} #{@@run_members} | cut -f 3`.split("\n")
    exp_table = expid_array.uniq.map do |expid|
      prsr = SRAMetadataParser::Experiment.new(expid, @xml_head + ".experiment.xml")
      if prsr
        { expid: expid,
          lib_layout: prsr.library_layout,
          platform: prsr.platform,
          instrument: prsr.instrument_model }
      end
    end
    exp_table.compact
  end
  
  def read_profile(runid)
    path = File.join(@@fqc_path, runid.slice(0..5), runid)
    Dir.entries(path).select{|f| f =~ /#{runid}/ }.map do |read|
      data_path = File.join(path, read, "fastqc_data.txt")
      prsr = FastQCParser.new(data_path)
      { read: read.sub(/_fastqc$/,""),
        total_seq: prsr.total_sequences,
        seq_length: prsr.sequence_length }
    end
  rescue Errno::ENOENT
    nil
  end
  
  def general_table
    study = self.study
    sample = self.sample
    experiment = self.experiment
    
    study_title = study[:study_title]
    study_type = study[:study_type]
    scientific_name = sample.map{|n| n[:scientific_name] }.uniq.join(", ")
    instrument = experiment.map{|n| n[:instrument] }.uniq.join(", ")
    
    { study_title: study_title,
      study_type: study_type,
      scientific_name: scientific_name,
      instrument: instrument }
  end
  
  def run_table
    line = `grep #{@studyid} #{@@run_members} | cut -f 1,3,4`.split("\n")
    run_exp_sample = line.map{|line| line.split("\t") }
    run_table = run_exp_sample.map do |res|
      runid = res[0]
      expid = res[1]
      sampleid = res[2]
      
      sample = self.sample.select{|n| n[:sampleid] == sampleid }.first
      experiment = self.experiment.select{|n| n[:expid] == expid }.first
      
      study_type = self.study[:study_type]
      organism = sample[:scientific_name]
      instrument = experiment[:instrument]
      lib_layout = experiment[:lib_layout]
      
      { runid: runid,
        expid: expid,
        sampleid: sampleid,
        study_type: study_type,
        organism: organism,
        instrument: instrument,
        lib_layout: lib_layout,
        read_profile: self.read_profile(runid) }
    end
  end
  
  def sample_table
    line = `grep #{@studyid} #{@@run_members} | cut -f 1,4`.split("\n")
    run_sample = line.map{|line| line.split("\t") }
    
    sample_runcount = {}
    run_sample.each do |rs|
      runid = rs[0]
      sampleid = rs[1]
      sample_runcount[sampleid] ||= []
      sample_runcount[sampleid].push(runid)
    end
    
    sample_runcount.keys.map do |sampleid|
      sample = self.sample.select{|n| n[:sampleid] == sampleid }.first
      sample_description = sample[:sample_description]
      { sampleid: sampleid,
        sample_description: sample_description,
        runid: sample_runcount[sampleid] }
    end
  end
  
  def paper
    if @paperinfo
      @paperinfo.map do |entry|
        pmid = entry[:pmid]
        arg = "db=pubmed&id=#{pmid}&retmode=xml"
        prsr = PubMedMetadataParser.new(open(@@eutil_base + arg).read)
        { pmid: pmid,
          journal: prsr.journal_title,
          title: prsr.article_title,
          abstract: prsr.abstract,
          affiliation: prsr.affiliation,
          authors: prsr.authors.map{|a| a.values.join("\s") },
          date: prsr.date_created.values.join("/") }
      end
    end
  end
  
  def pmc
    if @paperinfo
      pmcinfo = @paperinfo.map do |entry|
        pmid = entry[:pmid]
        pmcid = `grep -m 1 #{pmid} #{@@pmcid_table}`.split(",")[8]
        if pmcid
          arg = "db=pmc&id=#{pmcid}&retmode=xml"
          prsr = PMCMetadataParser.new(open(@@eutil_base + arg).read)
          body = prsr.body.compact
          introduction = body.select{|s| s[:sec_title] =~ /introduction|background/i }
          methods = body.select{|s| s[:sec_title] =~ /methods/i }
          results = body.select{|s| s[:sec_title] =~ /results/i }
          discussion = body.select{|s| s[:sec_title] =~ /discussion/i }
          
          { pmcid: pmcid,
            introduction: introduction,
            methods: methods,
            results: results,
            discussion: discussion,
            references: prsr.ref_journal_list,
            cited_by: prsr.cited_by }
        end
      end
      pmcinfo.compact if !pmcinfo.compact.empty?
    end
  end
  
  def report
    { general: self.general_table,
      paper: self.paper,
      pmc: self.pmc,
      run_table: self.run_table,
      sample_table: self.sample_table }
  end
end

def mess(message)
  puts message + "\t" + Time.now.strftime("%H:%M:%S")
end

if __FILE__ == $0
  require "ap"
  
  mess "loading config.yaml"
  ProjectReport.load_files("./config.yaml")
  
  id = "DRP000017" #"DRP000001"
  
  mess "creating ProjectReport object"
  pr = ProjectReport.new(id)
  
  mess "general table"
  ap pr.general_table.class

  mess "paper info"
  ap pr.paper.class

  mess "pmc info"
  ap pr.pmc.class
  
  mess "run table"
  ap pr.run_table.class

  mess "sample table"
  ap pr.sample_table.class
end
