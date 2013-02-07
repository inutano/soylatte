# -*- coding: utf-8 -*-

require "yaml"
require "groonga"
require "./parser_gen"

require "ap"

class MetadataParser
  def self.load_files(config_path)
    SRAParserGen.load_files(config_path)
    config = YAML.load_file(config_path)
    @@run_members = config["file_path"]["sra_run_members"]
    
    @@idtable_db = Groonga::Database.open(config["idtable_db_path"])
    @@db ||= Groonga["IDtable"]
  end
  
  def initialize(studyid)
    @studyid = studyid
    pgen = SRAParserGen.new(studyid, @@db)
    @sub_parser = pgen.submission_parser
    @study_parser = pgen.study_parser
    @exp_parser = pgen.experiment_parser
    @sample_parser = pgen.sample_parser
    @run_parser = pgen.run_parser
    @pub_parser = pgen.pubmed_parser
    @pmc_parser = pgen.pmc_parser
  end
  attr_reader :studyid
  
  def runid
    @@db.select{|r| r.project == @studyid }.map{|r| r.key.key }
    #`grep #{@studyid} #{@@run_members} | cut -f 1`.split("\n")
  end
  
  def study_title
    @study_parser.first.study_title
  end
  
  def taxonid
    @sample_parser.first.taxon_id
  rescue
    nil
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
    described_study_type = @study_parser.first.study_type
    app_ref[described_study_type]
  rescue
    nil
  end
  
  def instrument
    @exp_parser.first.instrument_model
  rescue
    nil
  end
  
  def full_text
    f_arr = []
    if @sub_parser
      @sub_parser.compact.each do |p|
        f_arr << [ p.submission_comment,
                   p.center_name,
                   p.lab_name ]
      end
    end
    if @study_parser
      @study_parser.compact.each do |p|
        f_arr << [ p.center_name,
                   p.center_project_name,
                   p.study_title,
                   p.study_type,
                   p.study_abstract,
                   p.study_description ]
      end
    end
    if @exp_parser
      @exp_parser.compact.each do |p|
        f_arr << [ p.center_name,
                   p.title,
                   p.design_description,
                   p.library_name,
                   p.platform,
                   p.instrument_model ]
      end
    end
    if @run_parser
      @run_parser.compact.each do |p|
        f_arr << [ p.center_name,
                   p.instrument_name,
                   p.run_center,
                   p.pipeline.map{|node| node[:program]} ]
      end
    end
    if @sample_parser
      @sample_parser.compact.each do |p|
        f_arr << [ p.title,
                   p.sample_description,
                   p.sample_detail.values,
                   p.taxon_id,
                   p.common_name,
                   p.scientific_name,
                   p.anonymized_name,
                   p.individual_name ]
      end
    end
    if @pub_parser
      @pub_parser.compact.each do |p|
        authors = p.authors.map{|a| a[:lastname] + " " + a[:forename] }
        mesh = p.mesh_terms.map{|a| a[:descriptor_name] }
        f_arr << [ authors,
                   mesh,
                   p.journal_title,
                   p.article_title,
                   p.abstract,
                   p.affiliation ]
      end
    end
    if @pmc_parser
      @pmc_parser.compact.each do |p|
        pmc_text = p.body.compact.map do |section|
          if section.has_key?(:subsec)
            section[:subsec].map do |subsec|
              subsec[:subsec_text]
            end
          else
            section[:sec_text]
          end
        end
        f_arr << [ pmc_text, p.keywords ]
      end
    end
    f_arr.flatten.join("\s")
  end
  
  def paper?
    true if @pub_parser
  end
  
  def insert
    { studyid: @studyid,
      runid: self.runid.length,
      study_title: self.study_title,
      taxonid: self.taxonid,
      study_type: self.study_type,
      instrument: self.instrument,
      fulltext: self.full_text,
      paper: self.paper? }
  end
end

if __FILE__ == $0
  require "ap"
  t00 = Time.now
  ap "load file"
  MetadataParser.load_files("../config.yaml")
  t01 = Time.now
  ap t01 - t00

=begin  
  db_path = "./id_table_db/idtable.db"
  Groonga::Database.open(db_path)
  db = Groonga["IDtable"]
=end
  
  ap "create object"
  #mp = MetadataParser.new("DRP000001", db)
  mp = MetadataParser.new(ARGV.first)
  t02 = Time.now
  ap t02 - t01
  
  t1 = Time.now
  ap "studyid"
  ap mp.studyid.class
  t2 = Time.now
  ap t2 - t1
  
  ap "runid"
  ap mp.runid.class
  t3 = Time.now
  ap t3 - t2
  
  ap "studytitle"
  ap mp.study_title.class
  t4 = Time.now
  ap t4 - t3
  
  ap "taxonid"
  ap mp.taxonid.class
  t5 = Time.now
  ap t5 - t4
  
  ap "studytype"
  ap mp.study_type.class
  t6 = Time.now
  ap t6 - t5
  
  ap "instrument"
  ap mp.instrument.class
  t7 = Time.now
  ap t7 - t6
  
  ap "fulltext"
  ap mp.full_text.class
  t8 = Time.now
  ap t8 - t7
  
  ap "paper?"
  ap mp.paper?.class
  t9 = Time.now
  ap t9 - t8
end
