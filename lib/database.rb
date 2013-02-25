# -*- coding: utf-8 -*-

require "singleton"
require "yaml"
require "groonga"
require "open-uri"

require File.expand_path(File.dirname(__FILE__)) + "/pubmed_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pmc_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/fastqc_result_parser"

class Database
  include Singleton
  attr_reader :grndb
  
  config_path = "/Users/inutano/project/soylatte/config.yaml"
  @@config = YAML.load_file(config_path)
  #@@db_path = YAML.load_file(config)["db_path"]
  @@db_path = "/Users/inutano/project/soylatte/lib/test_db/test.db"
  
  def initialize
    connect_db
  end
  
  def connect_db
    if !@grndb || @grndb.closed?
      @grndb = Groonga::Database.open(@@db_path)
      @projects = self.projects
      @runs = self.runs
      @samples = self.samples
    end
  end
  
  def projects
    @projects ||= Groonga["Projects"]
  end

  def runs
    @runs ||= Groonga["Runs"]
  end

  def samples
    @samples ||= Groonga["Samples"]
  end
  
  def type
    @projects.map{|r| r.study_type }.uniq.compact.sort
  end

  def instruments
    @runs.map{|r| r.instrument }.uniq.compact.sort
  end
  
  def species
    @samples.map{|r| r.scientific_name }.uniq.compact
  end
    
  def projects_size
    @projects.size
  end

  def runs_size
    @runs.size
  end

  def samples_size
    @samples.size
  end

  def filter_species(species)
    if !species or species.empty?
      @projects.map{|r| r["_key"] }
    else
      @projects.select{|r| r.run.sample.scientific_name =~ species }.map{|r| r["_key"] }
    end
  end
  
  def filter_type(type) # type: Genome, etc.
    if !type or type.empty?
      @projects.map{|r| r["_key"] }
    else
      ref = { "Genome" => ["Whole Genome Sequencing","Resequencing","Population Genomics","Exome Sequencing"],
              "Transcriptome" => ["Transcriptome Analysis","RNASeq"],
              "Epigenome" => ["Epigenetics","Gene Regulation Study"],
              "Metagenome" => ["Metagenomics"],
              "Cancer Genomics" => ["Cancer Genomics"],
              "Other" => ["Other","Pooled Clone Sequencing","Forensic or Paleo-genomics","Synthetic Genomics"] }
  
      described_types = ref[type]
      study_records = described_types.map do |study_type|
        @projects.select{|r| r.study_type == study_type }.map{|r| r["_key"] }
      end
      study_records.flatten.uniq
    end
  end
  
  def filter_instrument(instrument)
    if !instrument or instrument.empty?
      @projects.map{|r| r["_key"] }
    else
      @projects.select{|r| r.run.instrument =~ instrument }.map{|r| r["_key"] }
    end
  end
  
  def filter_result(species, type, instrument)
    filter_species = self.filter_species(species)
    filter_type = self.filter_type(type)
    filter_instrument = self.filter_instrument(instrument)
    mix = filter_species & filter_type & filter_instrument
    
    total = self.projects_size
    num_species = filter_species.size
    num_type = filter_type.size
    num_instrument = filter_instrument.size
    num_mix = mix.size
    
    ratio_species = ((num_species / total.to_f) * 100).round(2)
    ratio_type = ((num_type / total.to_f) * 100).round(2)
    ratio_instrument = ((num_instrument / total.to_f) * 100).round(2)
    ratio_mix = ((num_mix / total.to_f) * 100).round(2)
    
    { total: total,
      mix: [num_mix, ratio_mix],
      species: [num_species, ratio_species],
      type: [num_type, ratio_type],
      instrument: [num_instrument, ratio_instrument] }
  end
  
  def filtered_records(condition)
    # return array of study id meets the condition
    filter_species = self.filter_species(condition[:species])
    filter_type = self.filter_type(condition[:type])
    filter_instrument = self.filter_instrument(condition[:instrument])
    filter_species & filter_type & filter_instrument
  end
  
  def search(query, condition)
    hit = @projects.select{|r| r.search_fulltext =~ query }.map{|r| r["_key"] }
    filtered = self.filtered_records(condition)
    if query.empty?
      filtered.map{|id| @projects[id] }
    else
      (hit & filtered).map{|id| @projects[id] }
    end
  end
  
  def convert_to_study_id(id)
    case id.slice(2,1)
    when "P"
      id
    when "A"
      @projects.select{|r| r.submission_id =~ id }
    when "X"
      @projects.select{|r| r.run.experiment_id =~ id }
    when "S"
      @projects.select{|r| r.run.sample.key =~ id }
    when "R"
      @projects.select{|r| r.run.key =~ id }
    end
  end
  
  def search_with_id(id)
    if id
      record = self.convert_to_study_id(id)
      if record && record.size >= 1
        record.first["_key"]
      end
    end
  end
  
  def summary(study_id)
    p_record = @projects[study_id]
    r_record = p_record.run
    s_record = r_record.map{|r| r.sample }
    
    { study_id: study_id,
      study_title: p_record.study_title,
      type: p_record.study_type,
      species: s_record.map{|r| r.map{|s| s.scientific_name } }.flatten.uniq,
      instrument: r_record.map{|r| r.instrument }.uniq }
  end
  
  def paper(study_id)
    p_record = @projects[study_id]
    pmid_array = p_record.pubmed_id
    eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml"
    pmid_array.map do |pmid|
      arg = "&db=pubmed&id=#{pmid}"
      pm_parser = PubMedMetadataParser.new(open(eutil_base + arg).read)
      pmcid = pm_parser.pmcid
      { pubmed_id: pmid,
        journal: pm_parser.journal_title,
        title: pm_parser.article_title,
        abstract: pm_parser.abstract,
        affiliation: pm_parser.affiliation,
        authors: pm_parser.authors.map{|a| a.values.join("\s") },
        date: pm_parser.date_created.values.join("/"),
        pmc: self.pmc(pmcid) }
    end
  end
  
  def pmc(pmcid)
    if pmcid
      eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml"
      arg = "&db=pmc&id=#{pmcid}"
      pmc_parser = PMCMetadataParser.new(open(eutil_base + arg).read)
      body = pmc_parser.body.compact
      methods = body.select{|s| s[:sec_title] =~ /methods/i }
      results = body.select{|s| s[:sec_title] =~ /results/i }
      { pmc_id: pmcid,
        methods: methods,
        results: results,
        reference: pmc_parser.ref_journal_list,
        cited_by: pmc_parser.cited_by }
    end
  end
  
  def run_table(study_id)
    p_record = @projects[study_id]
    r_record = p_record.run
    r_record.map do |run|
      { run_id: run["_key"],
        experiment_id: run.experiment_id,
        submission_id: run.submission_id,
        sample_id: run.sample.map{|r| r["_key"] },
        study_type: p_record.study_type,
        instrument: run.instrument,
        lib_layout: run.library_layout,
        species: run.sample.map{|r| r.scientific_name }.uniq,
        read_profile: self.read_profile(run["_key"]) }
    end
  end
  
  def read_profile(run_id)
    path = File.join(@@config["fqc_path"], run_id.slice(0..5), run_id)
    Dir.entries(path).select{|f| f =~ /#{run_id}/ }.map do |read|
      data_path = File.join(path, read, "fastqc_data.txt")
      qc_parser = FastQCParser.new(data_path)
      { read_id: read.sub(/_fastqc$/,""),
        total_seq: qc_parser.total_sequences,
        seq_length: qc_parser.sequence_length }
    end
  rescue Errno::ENOENT
    nil
  end
  
  def sample_table(study_id)
    p_record = @projects[study_id]
    s_record = p_record.run.map{|r| r.sample.map{|s| s["_key"] }}
    s_record.flatten.uniq.map do |sid|
      { sample_id: sid,
        sample_description: @samples[sid].sample_description,
        run_id_list: @runs.select{|r| r.sample =~ sid }.map{|r| r["_key"] } }
    end
  end
  
  def project_report(study_id)
    { summary: self.summary(study_id),
      paper: self.paper(study_id),
      run_table: self.run_table(study_id),
      sample_table: self.sample_table(study_id) }
  end
  
  def run_report(read_id)
    run_id = read_id.slice(0..8)
    head = run_id.slice(0..5)
    fpath = File.join(@@config["fqc_path"], head, run_id, read_id + "_fastqc", "fastqc_data.txt")
    if File.exist?(fpath)
      parser = FastQCParser.new(fpath)
      { read_id: read_id,
        file_type: parser.file_type,
        encoding: parser.encoding,
        total_sequences: parser.total_sequences,
        filtered_sequences: parser.filtered_sequences,
        sequence_length: parser.sequence_length,
        percent_gc: parser.percent_gc,
        overrepresented_sequences: parser.overrepresented_sequences,
        kmer_content: parser.kmer_content }
    end
  end
  
  def description
    @projects.map{|r| r.search_fulltext }
  end
end

if __FILE__ == $0
  require "ap"
  db = Database.instance
  ap db.instruments
  ap db.species
  ap db.runs_size
  ap db.samples_size
  ap "filter: Homo sapiens, Transcriptome, Illumina Genome Analyzer"
  ap db.filter_result("Homo sapiens", "Transcriptome", "Illumina Genome Analyzer")
  
  query = ARGV.first
  if query =~ /(S|E|D)RP\d{6}/
    ap db.summary("DRP000001")
  elsif query
    ap ARGV.first + " , Homo sapiens, Transcriptome, Illumina GA"
    ap db.search(ARGV.first, species: "Homo sapiens", type: "Transcriptome", instrument: "Illumina Genome Analyzer")
  end
end
  
  
  
  
  
  
  
=begin  
  def size
    @db.size
  end
  
  def instruments
    @db.records.map{|r| r.instrument }.uniq.compact.sort
  end
  
  def scientific_names
    @db.records.map{|r| r.scientific_name }.uniq.compact.sort
  end
  
  def name2taxonid(name)
    @db.select{|r| r.scientific_name == name }.first.taxonid
  end
  
  def single_match_records(sym, cond)
    value = cond[sym]
    if value && value != ""
      match_records = @db.select do |record|
        record.send(sym) == value
      end
      num_of_records = match_records.size
      ratio = num_of_records / self.size.to_f
      ratio_to_percent = (ratio * 100).round(2)
      { size: num_of_records, percent: ratio_to_percent}
    else
      { size: self.size, percent: 100.0 }
    end
  end
  
  def mix_match_records(cond)
    taxonid = cond[:taxonid]
    study_type = cond[:study_type]
    instrument = cond[:instrument]
    table_taxon = if taxonid
                    @db.select{|r| r.taxonid == taxonid }
                  else
                    @db
                  end
    table_study_type = if study_type
                         table_taxon.select{|r| r.study_type == study_type }
                       else
                         table_taxon
                       end
    match_records = if !instrument.empty?
                      table_study_type.select{|r| r.instrument == instrument }
                    else
                      table_study_type
                    end
    
    num_of_records = match_records.size
    ratio = num_of_records / self.size.to_f
    ratio_to_percent = (ratio * 100).round(2)
    { size: num_of_records, percent: ratio_to_percent}
  end
    
  def filter(cond)
    result = {}
    cond.keys.each do |sym|
      result[sym] = single_match_records(sym, cond)
    end
    result[:mix] = mix_match_records(cond)
    result
  end
  
  def search_fulltext(query, condition)
    scientific_name = condition[:scientific_name]
    study_type = condition[:study_type]
    instrument = condition[:instrument]
    rec_species = if scientific_name and scientific_name != ""
                    @db.select{|r| r.scientific_name == scientific_name }
                  else
                    @db
                  end
    rec_study = if study_type and study_type != ""
                  rec_species.select{|r| r.study_type == study_type }
                else
                  rec_species
                end
    search_target = if instrument and instrument != ""
                      rec_study.select{|r| r.instrument == instrument }
                    else
                      rec_study
                    end
    if !query
      []
    elsif query == ""
      search_target.records
    else
      search_target.select{|r| r.fulltext =~ query }.records
    end
  end
end
=end
