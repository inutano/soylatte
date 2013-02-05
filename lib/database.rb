# -*- coding: utf-8 -*-

require "singleton"
require "yaml"
require "groonga"

class Database
  include Singleton
  attr_reader :grndb
  
  config = "/Users/inutano/project/soylatte/config.yaml"
  @@db_path = YAML.load_file(config)["db_path"]
  
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
#    @db ||= Groonga["Projects"]
    @db ||= Groonga["Facets"]
  end
  
  def size
    @db.size
  end
  
  def single_match_records(sym, cond)
    match_records = @db.select do |record|
      record.send(sym) == cond[sym]
    end
    num_of_records = match_records.size
    ratio = num_of_records / self.size.to_f
    ratio_to_percent = (ratio * 100).round(2)
    { size: num_of_records, percent: ratio_to_percent}
  end
  
  def mix_match_records(cond)
    table_taxon = @db.select do |record|
      record.taxonid == cond[:taxonid]
    end
    table_study_type = table_taxon.select do |record|
      record.study_type == cond[:study_type]
    end
    match_records = table_study_type.select do |record|
      record.instrument == cond[:instrument]
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
  
  def search_fulltext(query)
    @db.select{|r| r.fulltext =~ query }
  end
end
