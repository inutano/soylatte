# -*- coding: utf8 -*-

require "sra_metadata_parser"

class FacetParser
  def self.load_file
    
  end
  
  def initialize(runid)
    @runid = runid
  end
  
  def studyid
    "SRP000001"
  end
  
  def taxonid
    9606
  end
  
  def study_type
    1
  end
  
  def instrument
    "illumina HiSeq 2000"
  end
  
  def full_text
    "hogehoge"
  end
  
  def paper
    true
  end
  
  def insert
    { runid: @runid,
      studyid: self.studyid,
      taxonid: self.taxonid,
      study_type: self.study_type,
      instrument: self.instrument,
      fulltext: self.fulltext,
      paper: self.paper }
  end
end
