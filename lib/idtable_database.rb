# -*- coding: utf-8 -*-

require "singleton"
require "yaml"
require "groonga"

class IDtableDB
  include Singleton
  attr_reader :grndb
  
  config = "/Users/inutano/project/soylatte/config.yaml"
  @@db_path = YAML.load_file(config)["idtable_db_path"]
  
  def initialize
    open
  end
  
  def open
    if !@grndb || @grndb.closed?
      @grndb = Groonga::Database.open(@@db_path)
      @db = self.idtable
    end
  end
  
  def idtable
    @db ||= Groonga["IDtable"]
  end
  
  def convert_projectid(id)
    case id.slice(2,1)
    when "A"
      @db.select{|r| r.submission == id }.first.project
    when "P"
      id
    when "X"
      @db.select{|r| r.experiment == id }.first.project
    when "S"
      @db.select{|r| r.sample == id }.first.project
    when "R"
      @db.select{|r| r.key.key == id }.first.project
    end
  end
end

if __FILE__ == $0
  require "ap"
  db = Database.instance
end
