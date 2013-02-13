# -*- coding: utf-8 -*-

require "singleton"
require "yaml"
require "groonga"

class Database
  include Singleton
  attr_reader :grndb
  
  config = "/Users/inutano/project/soylatte/config.yaml"
  @@db_path = YAML.load_file(config)["project_db_path"]
  
  def initialize
    open
  end
  
  def open
    if !@grndb || @grndb.closed?
      @grndb = Groonga::Database.open(@@db_path)
      @db = self.projects
    end
  end
  
  def projects
    @db ||= Groonga["Projects"]
  end
  
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

if __FILE__ == $0
  require "ap"
  db = Database.instance
  ap db.instruments
#  ap db.scientific_names
end
