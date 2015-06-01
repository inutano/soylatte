# :)

require 'groonga'
require File.join(PROJ_ROOT, 'lib', 'repos', 'sra_metadata_toolkit', 'sra_metadata_parser')

class SoylatteDB
  class SRA
    include SRAMetadataParser
    
    def initialize(db, sub_id)
      @db = db
      @sub_id = sub_id
    end

    def load
      establish_connection
      [ :sample, :experiment, :study ].each do |type|
        load_data(xml_path(type))
      end
    end

    def establish_connection
      Groonga::Database.open(@db)
    end

    def xml_path(type)
      base = File.join(PROJ_ROOT, "data", "sra_metadata")
      File.join(base, @sub_id.sub(/...$/,""), @sub_id, @sub_id + ".#{type}.xml")
    end

    def load_data(xml)
      case xml
      when /study/
        node_list = Study.new(xml).parse
        node_list.each do |node|
          insert_study_record(node)
        end
      when /experiment/
        node_list = Experiment.new(xml).parse
        node_list.each do |node|
          insert_experiment_record(node)
        end
      when /sample/
        node_list = Sample.new(xml).parse
        node_list.each do |node|
          insert_sample_record(node)
        end
      end
    end

    def insert_study_record(node)
      study_id = node[:accession]

      study_id_record = Groonga["StudyIDs"][study_id]
      run_id_list    = study_id_record.run_id
      pubmed_id_list = study_id_record.pubmed_id
      pmc_id_list    = study_id_record.pmc_id

      Groonga["Projects"].add(
        study_id,
        submission_id: @sub_id,
        study_title:   node[:study_title],
        study_type:    node[:study_type],
        run:           run_id_list,
        pubmed_id:     pubmed_id_list,
        pmc_id:        pmc_id_list
      )
    end

    def insert_experiment_record(node)
      exp_id = node[:accession]
      run_id_list = Groonga["Experiments"][exp_id].run_id
      run_id_list.each do |run_id|
        Groonga["Runs"].add(
          run_id,
          submission_id: @sub_id,
          experiment_id: exp_id,
          sample: [node[:sample_accession]],
          instrument:             node[:platform_information][:instrument],
          library_strategy:       node[:library_description][:library_strategy],
          library_source:         node[:library_description][:library_source],
          library_selection:      node[:library_description][:library_selection],
          library_layout:         node[:library_description][:library_layout],
          library_orientation:    node[:library_description][:library_orientation],
          library_nominal_length: node[:library_description][:library_nominal_length],
          library_nominal_sdev:   node[:library_description][:library_nominal_sdev]
        )
      end
    end

    def insert_sample_record(node)
      taxon_id = node[:organism_information][:taxon_id]
      scientific_name = Groonga["Taxons"][taxon_id].scientific_name
      Groonga["Samples"].add(
        node[:accession],
        submission_id:      @sub_id,
        taxon_id:           taxon_id,
        scientific_name:    scientific_name,
        sample_title:       node[:title],
        sample_description: node[:sample_description]
      )
    end
  end
end
