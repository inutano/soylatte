# -*- coding: utf-8 -*-

require "singleton"
require "yaml"
require "groonga"

class Database
  include Singleton
  attr_reader :grndb
  
  #config = "/Users/inutano/project/soylatte/config.yaml"
  #@@db_path = YAML.load_file(config)["project_db_path"]
  config = "./config.yaml"
  @@db_path = "./test_db/test.db"
  
  def initialize
    open
  end
  
  def open
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
  
  def filter_species(species)
    if !species or species.empty?
      self.projects_size
    else
      sample_records = @samples.select{|r| r.scientific_name == species }
      sample_id_list = sample_records.map{|r| r["_key"] }
      
      run_records = sample_id_list.map do |sample_id|
        @runs.select{|r| r.sample =~ sample_id }.map{|r| r["_key"] }
      end
      run_id_list = run_records.flatten.uniq
      
      project_records = run_id_list.map do |run_id|
        @projects.select{|r| r.run =~ run_id }.map{|r| r["_key"] }
      end
      project_records.flatten.uniq.size
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
      study_records.flatten.uniq.size
    end
  end
  
  def filter_instrument(instrument)
    if !instrument or instrument.empty?
      self.projects_size
    else
      run_records = @runs.select{|r| r.instrument == instrument }
      run_id_list = run_records.map{|r| r["_key"] }
      
      project_records = run_id_list.map do |run_id|
        @projects.select{|r| r.run =~ run_id }.map{|r| r["_key"] }
      end
      project_records.flatten.uniq.size
    end
  end
  
  def filter_result(species, type, instrument)
    total = self.projects_size
    num_species = self.filter_species(species)
    num_type = self.filter_type(type)
    num_instrument = self.filter_instrument(instrument)
    
    ratio_species = ((num_species / total.to_f) * 100).round(2)
    ratio_type = ((num_type / total.to_f) * 100).round(2)
    ratio_instrument = ((num_instrument / total.to_f) * 100).round(2)
    
    { total: total,
      species: [num_species, ratio_species],
      type: [num_species, ratio_type],
      instrument: [num_species, ratio_instrument] }
  end
  
  def project_report(id)
    
  end
end

if __FILE__ == $0
  require "ap"
  db = Database.instance
  ap db.instruments
  ap db.species
  ap db.filter_result("Homo sapiens", "Genome", "Illumina Genome Analyzer")
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
