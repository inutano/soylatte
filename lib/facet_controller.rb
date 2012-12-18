# -*- coding: utf-8 -*-

require "groonga"

class FacetController
  def self.connect_db(db_path)
    Groonga::Context.default_options = { encoding: :utf8 }
    Groonga::Database.open(db_path)
  end
  
  def initialize
    @db = Groonga["Facets"]  
  end
  
  def close
    @db.close
  end
  
  def record(studyid)
    @db[studyid]
  end
  
  def size
    @db.size
  end
  
  def count_taxon_id(taxonid)
    @db.select{|record| record.taxonid == taxonid }.size
  end
  
  def count_study_type(study_type)
    @db.select{|record| record.study_type == study_type }.size
  end
  
  def count_instrument(instrument)
    @db.select{|record| record.instrument == instrument }.size
  end
  
  def count_on_demand(taxonid, study_type, instrument)
    tax = @db.select{|record| record.taxonid == taxonid }
    stu = tax.select{|record| record.study_type == study_type }
    stu.select{|record| record.instrument == instrument }.size
  end
  
  def search_fulltext(query)
    facets = Groonga["Facets"]
    search_result = facets.select{|record| record.fulltext =~ query }
    search_result.map{|record| record.key.key }
  end
end

if __FILE__ == $0
  require "ap"
  db_path = "../db/facet.db"
  FacetController.connect_db(db_path)
  db = FacetController.new
  
  ap db.size
  ap db.count_taxon_id(9606)
  ap db.count_study_type(1)
  ap db.count_instrument("Illumina Genome Analyzer II")
  
  ap db.count_on_demand(9606, 1, "Illumina Genome Analyzer II")
  
  ap db.search_fulltext("cancer")
  
  rec = db.record("DRP000001")
  ap rec
  ap rec.taxonid
  ap rec.study_type
  ap rec.instrument
end
