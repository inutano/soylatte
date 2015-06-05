# :)

require 'groonga'
require 'parallel'

class SoylatteDB
  class Reference
    class << self
      def load(db)
        establish_connection(db)
        pub_ref = sra_publications_pair
        load_subids(pub_ref)
        load_studyids(pub_ref)
        load_experiments
        load_taxons
      end

      def establish_connection(db)
        Groonga::Database.open(db)
      end
      
      ### publications pair ###
      
      def sra_publications_pair
        ref = pubmed_pmc_id_pair
        list = Parallel.map(publication_json, :in_threads => NUM_OF_PARALLEL) do |node|
          pubmed_id = node["pmid"]
          [ node["sra_id"], { pubmed_id: pubmed_id, pmc_id: ref[pubmed_id] } ]
        end
        Hash[list]
      end
      
      def publication_json
        publication_json = File.join(PROJ_ROOT, "data", "publication.json")
        open(publication_json){|f| JSON.load(f) }["ResultSet"]["Result"]
      end

      def pubmed_pmc_id_pair
        csv = File.join(PROJ_ROOT, "data", "PMC-ids.csv")
        pattern = '$4 > 2006 && $10 != "-" && $9 != "-" '
        cmd = "awk -F ',' 'BEGIN{ OFS=\"\t\" } #{pattern} { print $10, $9 }'"
        array = `#{cmd} #{csv}`.split("\n").map{|n| n.split("\t") }
        Hash[array]
      end

      ### submission ids ###
      
      def load_subids(pub_ref)
        db = Groonga["SubIDs"]
        pub_ref = sra_publications_pair
        submission_id_list.each do |sub_id, list_of_line|
          add_submission(db, sub_id, list_of_line.map{|l| l.split("\t")[1] }, pub_ref)
        end
      end
      
      def submission_id_list
        cmd = "awk -F '\t' 'BEGIN{ OFS=\"\t\" } $1 ~ /^.RP/ { print $2, $1 }'"
        accessions = File.join(PROJ_ROOT, "data", "sra_metadata", "SRA_Accessions")
        `#{cmd} #{accessions}`.split("\n").group_by{|node| node.split("\t")[0] } # group by submission id
      end
      
      def add_submission(db, sub_id, study_id_list, pub_ref)
        db.add(
          sub_id,
          study_id:  study_id_list,
          pubmed_id: get_pub_id(sub_id, pub_ref, :pubmed),
          pmc_id:    get_pub_id(sub_id, pub_ref, :pmc),
        )
      end
      
      def get_pub_id(sub_id, pub_ref, type)
        pubs = pub_ref[sub_id]
        if pubs
          case type
          when :pubmed
            pubs[:pubmed_id]
          when :pmc
            pubs[:pmc_id]
          end
        end
      end
      
      ### study ids ###
      
      def load_studyids(pub_ref)
        db = Groonga["StudyIDs"]
        study_id_list.each do |study_id, list_of_line|
          run_id_list = list_of_line.map{|l| l.split("\t")[1] }
          sub_id_list = list_of_line.map{|l| l.split("\t")[2] }
          add_study(db, study_id, run_id_list, sub_id_list, pub_ref)
        end
      end
      
      def study_id_list
        accessions = File.join(PROJ_ROOT, "data", "sra_metadata", "SRA_Accessions")
        cmd = "awk -F '\t' 'BEGIN{ OFS=\"\t\" } $1 ~ /^.RR/ { print $13, $1, $2 }' #{accessions}" # study_id, run_id, sub_id
        `#{cmd} #{accessions}`.split("\n").group_by{|node| node.split("\t")[0] } # sort by study id
      end
      
      def add_study(db, study_id, run_id_list, sub_id_list, pub_ref)
        db.add(
          study_id,
          run_id:    run_id_list,
          pubmed_id: sub_id_list.map{|sub_id| get_pub_id(sub_id, pub_ref, :pubmed) }.compact,
          pmc_id:    sub_id_list.map{|sub_id| get_pub_id(sub_id, pub_ref, :pmc) }.compact,
        )
      end
      
      ### experiments ###
      
      def load_experiments
        db = Groonga["Experiments"]
        exp_run_id_list.each do |exp_id, list_of_line|
          run_id_list = list_of_line.map{|l| l.split("\t")[1] }
          add_experiment(db, exp_id, run_id_list)
        end
      end
      
      def exp_run_id_list
        accessions = File.join(PROJ_ROOT, "data", "sra_metadata", "SRA_Accessions")
        cmd = "awk -F '\t' 'BEGIN{ OFS=\"\t\" } $1 ~ /^.RR/ { print $11, $1 }' #{accessions}" # exp_id, run_id
        `#{cmd} #{accessions}`.split("\n").group_by{|n| n.split("\t")[0] }
      end
      
      def add_experiment(db, exp_id, run_id_list)
        db.add(
          exp_id,
          run_id: run_id_list
        )
      end
      
      ### taxonomy ###
      
      def load_taxons
        db = Groonga["Taxons"]
        taxon_list.each do |ln|
          line = ln.split("\t")
          add_taxon(db, line[0], line[1])
        end
      end
      
      def taxon_list
        taxon_table = File.join(PROJ_ROOT, "data", "taxon_table.csv")
        cmd = "awk -F ',' 'BEGIN{ OFS=\"\t\" }{ print $1, $2 }'"
        `#{cmd} #{taxon_table}`.split("\n")
      end
      
      def add_taxon(db, taxon_id, s_name)
        db.add(
          taxon_id,
          scientific_name: s_name
        )
      end
    end
  end
end
