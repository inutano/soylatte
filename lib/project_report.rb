# -*- coding: utf-8 -*-

require "yaml"
require "#{File.expand_path(File.dirname(__FILE__))}/parser_gen"

class ProjectReport
  def self.load_files(config_path)
    SRAParserGen.load_files(config_path)
  end
  
  def initialize(studyid)
    @studyid = studyid
    @pgen = SRAParserGen.new(studyid)
  end
  
  def project_info
    study_parser = @pgen.study_parser
    if study_parser.size == 1
      sp = study_parser.first
      { study_title: sp.study_title,
        study_type: sp.study_type }
    end
  end
  
  def paper_info
    pub_parser = @pgen.pubmed_parser
    pub_parser.select{|n| n }.map do |pp|
      { pmid: pp.pmid,
        journal: pp.journal_title,
        title: pp.article_title,
        abstract: pp.abstract,
        affiliation: pp.affiliation,
        authors: pp.authors.map{|a| a.values.join("\s")},
        date: pp.date_created.values.join("/") }
    end
  end
  
  def pmc_info
    pmc_parser = @pgen.pmc_parser
    pmc_parser.select{|n| n }.map do |pp|
      body = pp.body.select{|sec| sec }
      { pmcid: pp.pmcid,
        journal_title: pp.journal_title,
        introduction: body.select{|s| s[:sec_title] =~ /introduction/i },
        methods: body.select{|s| s[:sec_title] =~ /method/i },
        results: body.select{|s| s[:sec_title] =~ /result/i },
        discussion: body.select{|s| s[:sec_title] =~ /discussion/i },
        references: pp.ref_journal_list,
      }
    end
  end
  
  def experiment_info
    exp_parser = @pgen.experiment_parser
    exp_parser.select{|n| n }.map do |ep|
      { sampleid: ep.sample_accession,
        lib_layout: ep.library_layout,
        platform: ep.platform,
        lib_protocol: ep.library_construction_protocol,
        instrument: ep.instrument_model }
    end
  end
  
  def sample_info
    sample_parser = @pgen.sample_parser
    sample_parser.select{|n| n }.map do |sp|
      { taxonid: sp.taxon_id,
        common_name: sp.common_name,
        scientific_name: sp.scientific_name }
    end
  end
  
  def run_info
    run_parser = @pgen.run_parser
    run_parser.select{|n| n }.map do |rp|
      # nothing
    end
  end
  
  def report
    { project: self.project_info,
      paper: self.paper_info,
      pmc: self.pmc_info,
      experiment: self.experiment_info,
      sample_info: self.sample_info }
  end
end

if __FILE__ == $0
  require "ap"
  ProjectReport.load_files("./config.yaml")
  id = "DRP000001"
  pr = ProjectReport.new(id)
  ap pr.report
end
