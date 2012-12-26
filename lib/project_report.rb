# -*- coding: utf-8 -*-

require "yaml"
require "#{File.expand_path(File.dirname(__FILE__))}/parser_gen"

class ProjectReport
  def load_files(config_path)
    SRAParserGen.load_files(config_path)
  end
  
  def initialize(studyid)
    @studyid = studyid
    pgen = SRAParserGen.new(studyid)
    @sub_parser = pgen.submission_parser
    @study_parser = pgen.study_parser
    @exp_parser = pgen.experiment_parser
    @sample_parser = pgen.sample_parser
    @run_parser = pgen.run_parser
    @pub_parser = pgen.pubmed_parser
    @pmc_parser = pgen.pmc_parser
  end
  
  def general_info
    { study_title: @study_parser.first.study_title,
      study_abstract: @study_parser.first.study_abstract,
      study_description: @study_parser.first.study_description,
      num_of_exp: @exp_parser.size,
      num_of_sample: @sample_parser.size,
      num_of_run: @run_parser.size }
  end
  
  def paper_info
    @pub_parser.select{|n| n }.map do |pp|
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
  end
  
  def before_seq
  end
  
  def sequencing
  end
  
  def after_seq
  end
  
  def report
  end
end
