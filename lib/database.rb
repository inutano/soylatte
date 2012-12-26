# -*- coding: utf-8 -*-

require "singleton"
require "yaml"
require "groonga"

class Database
  include Singleton
  attr_reader :grndb
  
  config = "/Users/inutano/project/soylatte/lib/config.yaml"
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
    @db ||= Groonga["Projects"]
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
    { sym => { size: num_of_records, percent: ratio_to_percent} }
  end
  
  def mix_match_records(cond)
    match_records = @db.select do |record|
      ev = cond.keys.map{|sym| record.send(sym) == cond[sym] }
      !ev.include?(false)
    end
    num_of_records = match_records.size
    ratio = num_of_records / self.size.to_f
    ratio_to_percent = (ratio * 100).round(2)
    { mix: { size: num_of_records, percent: ratio_to_percent} }
  end
    
  def filter(cond)
    singles = cond.keys.map{|sym| single_match_records(sym, cond) }
    mix = mix_match_records(cond)
    singles << mix
  end
  
  def search_fulltext(query)
    result = @db.select{|r| r.fulltext =~ query }
    result.map{|r| r.key.key }
  end
end
