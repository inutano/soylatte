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
        node_list  = Study.new(xml).parse
        studydb    = Groonga["StudyIDs"]
        projectdb = Groonga["Projects"]
        node_list.each do |node|
          insert_study_record(node, studydb, projectdb)
        end
      when /experiment/
        node_list    = Experiment.new(xml).parse
        experimentdb = Groonga["Experiments"]
        rundb        = Groonga["Runs"]
        node_list.each do |node|
          insert_experiment_record(node, experimentdb, rundb)
        end
      when /sample/
        node_list = Sample.new(xml).parse
        taxondb   = Groonga["Taxons"]
        sampledb  = Groonga["Samples"]
        node_list.each do |node|
          insert_sample_record(node, taxondb, sampledb)
        end
      end
    end

    def insert_study_record(node, studydb, projectdb)
      study_id = node[:accession]
      study_id_record = studydb[study_id]
      add_project(node, study_id, projectdb, study_id_record)
    end
    
    def add_project(node, study_id, projectdb, study_id_record)
      projectdb.add(
        study_id,
        submission_id: @sub_id,
        study_title:   node[:study_title],
        study_type:    node[:study_type],
        run:           study_id_record.run_id,
        pubmed_id:     study_id_record.pubmed_id,
        pmc_id:        study_id_record.pmc_id
      )
    end

    def insert_experiment_record(node, experimentdb, rundb)
      exp_id = node[:accession]
      run_id_list = experimentdb[exp_id].run_id
      run_id_list.each do |run_id|
        add_run(node, rundb, run_id, exp_id)
      end
    end
    
    def add_run(node, rundb, run_id, exp_id)
      rundb.add(
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

    def insert_sample_record(node, taxondb, sampledb)
      taxon_id = node[:organism_information][:taxon_id]
      s_name   = taxondb[taxon_id].scientific_name
      add_sample(node, sampledb, taxon_id, s_name)
    end
    
    def add_sample(node, sampledb, taxon_id, s_name)
      sampledb.add(
        node[:accession],
        submission_id:      @sub_id,
        taxon_id:           taxon_id,
        scientific_name:    s_name,
        sample_title:       node[:title],
        sample_description: node[:sample_description]
      )
    end
  end
end
