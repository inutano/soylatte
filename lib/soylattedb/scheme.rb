# :)

require 'groonga'

class SoylatteDB
  class Scheme
    class << self
      def up(db)
        Groonga::Database.create(:path => db)

        Groonga::Schema.define do |schema|
          schema.create_table("StudyIDs", :type => :hash) do |table|
            table.short_text("run_id", type: :vector)
            table.short_text("pubmed_id", type: :vector)
            table.short_text("pmc_id", type: :vector)
          end

          schema.create_table("SubIDs", :type => :hash) do |table|
            table.short_text("study_id", type: :vector)
            table.short_text("pubmed_id", type: :vector)
            table.short_text("pmc_id", type: :vector)
          end

          schema.create_table("Experiments", :type => :hash) do |table|
            table.short_text("run_id", type: :vector)
          end

          schema.create_table("Taxons", :type => :hash) do |table|
            table.short_text("scientific_name")
          end

          schema.create_table("Samples", :type => :hash) do |table|
            table.short_text("sample_title")
            table.text("sample_description")
            table.short_text("taxon_id")
            table.short_text("scientific_name")
            table.short_text("submission_id")
          end

          schema.create_table("Runs", type: :hash) do |table|
            table.short_text("experiment_id")
            table.short_text("library_strategy")
            table.short_text("library_source")
            table.short_text("library_selection")
            table.short_text("library_layout")
            table.short_text("library_orientation")
            table.short_text("library_nominal_length")
            table.short_text("library_nominal_sdev")
            table.short_text("instrument")
            table.short_text("submission_id")
            table.reference("sample", "Samples", type: :vector)
          end

          schema.create_table("Projects", type: :hash) do |table|
            table.short_text("study_title")
            table.short_text("study_type")
            table.reference("run", "Runs", type: :vector)
            table.short_text("submission_id", type: :vector)
            table.short_text("pubmed_id", type: :vector)
            table.short_text("pmc_id", type: :vector)
            table.long_text("search_fulltext")
          end

          schema.create_table("Index_text",
            type: :patricia_trie,
            key_normalize: true,
            default_tokenizer: "TokenBigram"
          )
          schema.change_table("Index_text") do |table|
            table.index("Samples.taxon_id")
            table.index("Samples.scientific_name")
            table.index("Runs.instrument")
            table.index("Runs.experiment_id")
            table.index("Projects.study_type")
            table.index("Projects.submission_id")
            table.index("Projects.pubmed_id")
            table.index("Projects.pmc_id")
            table.index("Projects.search_fulltext")
          end

          schema.change_table("Samples") do |table|
            table.index("Runs.sample")
          end

          schema.change_table("Runs") do |table|
            table.index("Projects.run")
          end
        end
      end
    end
  end
end
