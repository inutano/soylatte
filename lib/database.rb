# -*- coding: utf-8 -*-

require "singleton"
require "yaml"
require "groonga"
require "open-uri"

require File.expand_path(File.dirname(__FILE__)) + "/pubmed_metadata_parser"
require File.expand_path(File.dirname(__FILE__)) + "/pmc_metadata_parser"

class Database
  include Singleton
  attr_reader :grndb
  
  #config = "/Users/inutano/project/soylatte/config.yaml"
  #@@db_path = YAML.load_file(config)["project_db_path"]
  config = "./config.yaml"
  @@db_path = "./test_db/test.db"
  
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
      self.projects_size
    else
      @projects.select{|r| r.run.sample.scientific_name =~ species }.map{|r| r["_key"] }
    end
  end
  
  def filter_type(type) # type: Genome, etc.
    if !type or type.empty?
      self.projects_size
    else
      ref = { "Genome" => ["Whole Genome Sequencing","Resequencing","Population Genomics","Exome Sequencing"],
              "Transcriptome" => ["Transcriptome Analysis","RNASeq"],
              "Epigenome" => ["Epigenetics","Gene Regulation Study"],
              "Metagenome" => ["Metagenomics"],
              "Cancer Genome" => ["Cancer Genomics"],
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
      self.projects_size
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
  
  def search(query, condition)
    hit = @projects.select{|r| r.search_fulltext =~ query }.map{|r| r["_key"] }
    filter_species = self.filter_species(condition[:species])
    filter_type = self.filter_type(condition[:type])
    filter_instrument = self.filter_instrument(condition[:instrument])
    hit & filter_species & filter_type & filter_instrument
  end
  
  def summary(id)
    p_record = @projects[id]
    r_record = p_record.run
    s_record = r_record.map{|r| r.sample }
    
    { study_id: id,
      study_title: p_record.study_title,
      type: p_record.study_type,
      species: s_record.map{|r| r.map{|s| s.scientific_name } }.flatten.uniq,
      instrument: r_record.map{|r| r.instrument }.uniq }
  end
  
  def paper(id)
    p_record = @projects[id]
    pmid_array = p_record.pubmed_id
    eutil_base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml"
    pmid_array.map do |pmid|
      arg = "&db=pubmed&id=#{pmid}"
      pm_parser = PubMedMetadataParser.new(open(eutil_base + arg).read)
      pmcid = pm_parser.pmcid
      { pmid: pmid,
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
      { pmcid: pmcid,
        methods: methods,
        results: results,
        reference: pmc_parser.ref_journal_list,
        cited_by: pmc_parser.cited_by }
    end
  end
  
  def project_report(id)
    { summary: self.summary(id),
      paper: self.paper(id),
      run_table: self.run_table(id),
      sample_table: self.sample_table(id) }
  end
end

if __FILE__ == $0
  require "ap"
  db = Database.instance
  ap db.instruments
  ap db.species
  ap db.filter_result("Homo sapiens", "Genome", "Illumina Genome Analyzer")
  ap db.search(ARGV.first, species: "Homo sapiens", type: "Genome", instrument: "Illumina Genome Analyzer")
  ap db.runs_size
  ap db.samples_size
  ap db.summary("DRP000001")
  ap db.paper("DRP000001")
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
