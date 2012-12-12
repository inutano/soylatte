# -*- coding: utf-8 -*-

require "yaml"
require "./parser_gen"

class FacetParser
  def self.load_files(config_path)
    SRAParserGen.load_files(config_path)
    @@run_members = YAML.load_file(config_path)["file_path"]["sra_run_members"]
  end
  
  def initialize(runid)
    @runid = runid
    pgen = SRAParserGen.new(runid)
    @sub_parser = pgen.submission_parser
    @study_parser = pgen.study_parser
    @exp_parser = pgen.experiment_parser
    @sample_parser = pgen.sample_parser
    @run_parser = pgen.run_parser
    @pub_parser = pgen.pubmed_parser
    @pmc_parser = pgen.pmc_parser
  end
  
  def studyid
    `grep #{@runid} #{@@run_members} | cut -f 5`.chomp
  end
  
  def taxonid
    @sample_parser.first.taxon_id
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
  end
  
  def instrument
    @exp_parser.first.instrument_model
  end
  
  def full_text
    f_arr = []
    @sub_parser.select{|p| p }.each do |p|
      f_arr << [ p.submission_comment,
                 p.center_name,
                 p.lab_name ]
    end
    @study_parser.select{|p| p }.each do |p|
      f_arr << [ p.center_name,
                 p.center_project_name,
                 p.study_title,
                 p.study_type,
                 p.study_abstract,
                 p.study_description ]
    end
    @exp_parser.select{|p| p }.each do |p|
      f_arr << [ p.center_name,
                 p.title,
                 p.design_description,
                 p.library_name,
                 p.platform,
                 p.instrument_model ]
    end
    @run_parser.select{|p| p }.each do |p|
      f_arr << [ p.center_name,
                 p.instrument_name,
                 p.run_center,
                 p.pipeline.map{|node| node[:program]} ]
    end
    @sample_parser.select{|p| p }.each do |p|
      f_arr << [ p.title,
                 p.sample_description,
                 p.sample_detail.values,
                 p.taxon_id,
                 p.common_name,
                 p.scientific_name,
                 p.anonymized_name,
                 p.individual_name ]
    end
    @pub_parser.select{|p| p }.each do |p|
      authors = p.authors.map{|a| a[:lastname] + " " + a[:forename] }
      mesh = p.mesh_terms.map{|a| a[:descriptor_name] }
      f_arr << [ authors,
                 mesh,
                 p.journal_title,
                 p.article_title,
                 p.abstract,
                 p.affiliation ]
    end
    @pmc_parser.select{|p| p }.each do |p|
      pmc_text = p.body.select{|n| n }.map do |section|
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
    f_arr.flatten.join("\s")
  end
  
  def paper?
    !@pub_parser.select{|p| p }.empty?
  end
  
  def insert
    { runid: @runid,
      studyid: self.studyid,
      taxonid: self.taxonid,
      study_type: self.study_type,
      instrument: self.instrument,
      fulltext: self.full_text,
      paper: self.paper? }
  end
end

if __FILE__ == $0
  require "ap"
  FacetParser.load_files("./config.yaml")
  fp = FacetParser.new("DRR000001")
  
  puts fp.insert
end
