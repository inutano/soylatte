# -*- coding: utf8 -*-

require "yaml"
require "sra_metadata_parser"

class FacetParser
  def self.load_file(config_path)
    config = YAML.load_file(config_path)
    file_path = config["file_path"]
    @accessions = file_path["accessions"]
    @run_members = file_path["run_members"]
    @xbase = file_path["sra_metadata_xml"]
  end
  
  def initialize(runid)
    @runid = runid
    @subid = `grep #{@runid} #{accessions} | cut -f 2`.chomp
    @xml_path_head = File.join(@xbase, @subid.slice(0,6), @subid)
  end
  
  def studyid
    `grep #{@runid} #{@run_members} | cut -f 5`.chomp
    #"SRP000001"
  end
  
  def sampleid
    `grep #{@runid} #{run_members} | cut -f 4`.chomp
  end
  
  def expid
    `grep #{@runid} #{@run_member} | cut -f 3`.chomp
  end
  
  def taxonid
    xml = File.join(@xml_path_head, "#{@subid}.sample.xml")
    parser = SRAMetadataParser::Sample.new(self.sampleid, xml)
    parser.taxon_id
    #9606
  end
  
  def study_type
    app_ref = { "Whole Genome Sequencing" => 1,
                "Transcriptome Analysis" => 2,
                "Metagenomics" => 4,
                "Epigenetics" => 3,
                "Other" => 0,
                "RNASeq" => 2,
                "Resequencing" => 1,
                "Population Genomics" => 1,
                "Gene Regulation Study" => 3,
                "Pooled Clone Sequencing" => 0,
                "Cancer Genomics" => 5,
                "Exome Sequencing" => 1,
                "Forensic or Paleo-genomics" => 0,
                "Synthetic Genomics" => 0 }
    xml = File.join(@xml_path_head, "#{@subid}.study.xml")
    parser = SRAMetadataParser::Study.new(self.studyid, xml)
    described_study_type = parser.study_type
    app_ref[described_study_type]
    #1
  end
  
  def instrument
    xml = File.join(@xml_path_head, "#{@subid}.experiment.xml")
    parser = SRAMetadataParser::Experiment.new(self.expid, xml)
    parser.instrument_model
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
