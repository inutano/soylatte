# -*- coding: utf-8 -*-

require "yaml"
require "groonga"
require "json"
require "open-uri"
require "parallel"

require File.expand_path(File.dirname(__FILE__)) + "/sra_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pubmed_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pmc_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/fastqc_result_parser"

class ProjectReport
  config_path = "/Users/inutano/project/soylatte/config.yaml"
  @@db_path = YAML.load_file(config_path)["idtable_path"]
  
  def initialize(studyid, config_path)
    @studyid = studyid
    @config = YAML.load_file(config_path)
    self.connect_db
    self.get_records

    subid_a = @records.map{|r| r.submission }.uniq
    if subid_a.size > 1
      raise ArgumentError
    else
      subid = subid_a.first
      xmlbase = @config["file_path"]["xmlbase"]
      @xml = File.join(xmlbase, subid.slice(0..5), subid, subid)
    end
    
    raw_json = open(@config["file_path"]["publication"]).read
    json = JSON.parse(raw_json, :symbolize_names => true)
    @paper = json[:ResultSet][:Result].select{|ent| ent[:sra_id] == subid }
    @pmcid_table = @config["file_path"]["PMC-ids"]
    @eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?"
  end
  attr_reader :iddb
  
  def connect_db
    if !@iddb || @iddb.closed?
      @iddb = Groonga::Database.open(@@db_path)
      @db ||= Groonga["IDtable"]
    end
  end
  
  def get_records
    @records ||= @db.select{|r| r.project == @studyid }
  end
  
  def study_info
    study_parser = SRAMetadataParser::Study.new(@studyid, @xml + ".study.xml")
    { study_title: study_parser.study_title,
      study_type: study_parser.study_type }
  end
  
  def experiment_info
    hash = {}
    exp_xml = @xml + ".experiment.xml"
    @records.map{|r| r.experiment }.uniq.each do |expid|
      exp_parser = SRAMetadataParser::Experiment.new(expid, exp_xml)
      if exp_parser
        hash[expid] = { lib_layout: exp_parser.library_layout,
                        instrument: exp_parser.instrument_model }
      end
    end
    hash
  end
  
  def sample_info
    hash = {}
    sample_xml = @xml + ".sample.xml"
    @records.map{|r| r.sample }.uniq.each do |sampleid|
      sample_parser = SRAMetadataParser::Sample.new(sampleid, sample_xml)
      if sample_parser
        taxonid = sample_parser.taxon_id
        hash[sampleid] = { sample_description: sample_parser.sample_description,
                           taxonid: taxonid,
                           scientific_name: self.taxonid2sname(taxonid) }
      end
    end
    hash
  end
  
  def taxonid2sname(taxonid)
    taxon_table = @config["file_path"]["taxon_table"]
    `grep -m 1 '^#{taxonid}' #{taxon_table} | cut -d ',' -f 2`.chomp
  end
  
  def read_info(runid)
    path = File.join(@config["fqc_path"], runid.slice(0..5), runid)
    Dir.entries(path).select{|f| f =~ /#{runid}/ }.map do |read|
      data_path = File.join(path, read, "fastqc_data.txt")
      qc_parser = FastQCParser.new(data_path)
      { read: read.sub(/_fastqc$/,""),
        total_seq: qc_parser.total_sequences,
        seq_length: qc_parser.sequence_length }
    end
  rescue Errno::ENOENT
    nil
  end
  
  def paper
    if @paper
      @paper.map do |entry|
        pmid = entry[:pmid]
        arg = "db=pubmed&id=#{pmid}&retmode=xml"
        pm_parser = PubMedMetadataParser.new(open(@eutil_base + arg).read)
        pmcid = pm_parser.pmcid
        { pmid: pmid,
          journal: pm_parser.journal_title,
          title: pm_parser.article_title,
          abstract: pm_parser.abstract,
          affiliation: pm_parser.affiliation,
          authors: pm_parser.authors.map{|a| a.values.join("\s") },
          date: pm_parser.date_created.values.join("/"),
          pmc: self.pmc(pmcid)}
      end
    end
  end
  
  def pmc(pmcid)
    if pmcid
      arg = "db=pmc&id=#{pmcid}&retmode=xml"
      pmc_parser = PMCMetadataParser.new(open(@eutil_base + arg).read)
      body = pmc_parser.body.compact
      methods = body.select{|s| s[:sec_title] =~ /methods/i }
      results = body.select{|s| s[:sec_title] =~ /results/i }
      { pmcid: pmcid,
        methods: methods,
        results: results,
        reference: pmc_parser.ref_journal_list,
        cited_by: pmc_parser.cited_by }
    end
  end
  
  def report
    study_info = self.study_info
    experiment_info = self.experiment_info
    sample_info = self.sample_info
    
    general = { studyid: @studyid,
                study_title: study_info[:study_title],
                study_type: study_info[:study_type],
                scientific_name: sample_info.values.map{|n| n[:scientific_name] }.uniq.join(", "),
                instrument: experiment_info.values.map{|n| n[:instrument]}.uniq.join(",") }
    
    runids = @records.map{|r| r.key.key }
    run_table = Parallel.map(runids) do |runid|
      rec = @db[runid]
      subid = rec.submission
      expid = rec.experiment
      sampleid = rec.sample
      
      if experiment_info.has_key?(expid)
        instrument = experiment_info[expid][:instrument]
        lib_layout = experiment_info[expid][:lib_layout]
      else
        exp_xml = @xml + ".experiment.xml"
        exp_parser = SRAMetadataParser::Experiment.new(expid, exp_xml)
        if exp_parser
          instrument = exp_parser.instrument_model
          lib_layout = exp_parser.library_layout
        else
          insturment = "no data"
          lib_layout = "no data"
        end
      end
      
      if sample_info.has_key?(sampleid)
        scientific_name = sample_info[sampleid][:scientific_name]
      else
        sample_xml = @xml + ".sample.xml"
        sample_parser = SRAMetadataParser::Sample.new(sampleid, sample_xml)
        if sample_parser
          taxonid = sample_parser.taxon_id
          scientific_name = taxonid2sname(taxonid)
        else
          scientific_name = "no data"
        end
      end
      
      { runid: runid,
        subid: subid,
        expid: expid,
        sampleid: sampleid,
        study_type: study_info[:study_type],
        instrument: instrument,
        lib_layout: lib_layout,
        organism: scientific_name,
        read_profile: self.read_info(runid) }
    end
    
    sample_runcount = {}
    sample_run = run_table.each do |n|
      runid = n[:runid]
      sampleid = n[:sampleid]
      sample_runcount[sampleid] ||= []
      sample_runcount[sampleid].push(runid)
    end
  
    sample_table = sample_runcount.keys.map do |sampleid|
      { sampleid: sampleid,
        sample_description: sample_info[sampleid][:sample_description],
        runid: sample_runcount[sampleid] }
    end
    
    { general: general,
      paper: self.paper,
      run_table: run_table,
      sample_table: sample_table }
  end
end

if __FILE__ == $0
  require "ap"
  ap Time.now
  config_path = "../config.yaml"
  ids = ["DRP000169", "DRP000017", "DRP000001"]
  ids.each do |id|
    ap ProjectReport.new(id, config_path).report.class
    ap Time.now
  end
end
