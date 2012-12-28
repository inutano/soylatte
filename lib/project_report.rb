# -*- coding: utf-8 -*-

require "yaml"
require "#{File.expand_path(File.dirname(__FILE__))}/parser_gen"

class ProjectReport
  def load_files(config_path)
    SRAParserGen.load_files(config_path)
  end
  
  def initialize(studyid)
    @studyid = studyid
    @pgen = SRAParserGen.new(studyid)
  end
  
  def project_info
    study_parser = pgen.study_parser
    if study_parser.size == 1
      sp = study_parser.first
      { study_title: sp.study_title,
        study_abstract: sp.study_abstract,
        study_description: sp.study_description,
        num_of_exp: @exp_parser.size,
        num_of_sample: @sample_parser.size,
        num_of_run: @run_parser.size }
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
      { pmcid: pp.pmcid,
        journal_title: pp.journal_title,
        introduction: pp.body.select{|s| s[:sec_title] =~ /introduction/i },
        methods: pp.body.select{|s| s[:sec_title] =~ /method/i },
        results: pp.body.select{|s| s[:sec_title] =~ /result/i },
        discussion: pp.body.select{|s| s[:sec_title] =~ /discussion/i },
        references: pp.ref_journal_list,
      }
    end
  end
  
  def experiment_info
    exp_parser = @pgen.experiment_parser
    exp_parser.select{|n| n }.map do |ep|
      { exp_title: ep.title,
        design_description: ep.design_description,
        sampleid: ep.sample_accession,
        lib_name: ep.library_name,
        lib_strategy: ep.library_strategy,
        lib_source: ep.library_source,
        lib_selection: ep.library_selection,
        lib_layout: ep.library_layout,
        lib_protocol: ep.library_construction_protocol,
        platform: ep.platform,
        instrument: ep.instrument_model }
    end
  end
  
  def sample_info
    sample_parser = @pgen.sample_parser
    sample_parser.select{|n| n }.map do |sp|
      { title: sp.title,
        description: sp.sample_description,
        taxonid: sp.taxon_id,
        common_name: sp.common_name,
        scientific_name: sp.scientific_name,
        }
    end
  end
  
  def run_info
    run_parser = @pgen.run_parser
    run_parser.select{|n| n }.map do |rp|
      # nothing
    end
  end
  
  def report
  end
end
