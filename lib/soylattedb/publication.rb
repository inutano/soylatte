# :)

require 'groonga'
require File.join(PROJ_ROOT, 'lib', 'repos', 'opPMC', 'publication_metadata_parser')

class SoylatteDB
  class Publication
    class << self
      include PublicationMetadataParser

      def load(db, sub_id_list)
        pubmed_id_pair, pmc_id_pair = create_pairs(sub_id_list)
        load_pub(db, :pubmed, pubmed_id_pair)
        load_pub(db, :pmc, pmc_id_pair)
      end

      def create_pairs(sub_id_list)
        pubmed_id_pair = Hash.new{|h,k| h[k] = [] }
        pmc_id_pair    = Hash.new{|h,k| h[k] = [] }
        
        sub_id_list.each do |sub_id|
          record = Groonga["SubIDs"][sub_id]
          record.study_id.each do |study_id|
            pubmed_id_pair[record.pubmed_id] << study_id
            pmc_id_pair[record.pmc_id]       << study_id
          end
        end
        [pubmed_id_pair, pmc_id_pair]
      end

      def load_pub(db, type, pub_id_pairs)
        pub_id_pairs.each_slice(100) do |node|
          pairs = Hash[node]
          pub_id_text_pairs = bulk_parse(type, pairs.keys)

          pub_id_text_pairs.each_pair do |pub_id, text|
            study_id_list = pairs[pub_id]
            study_id_list.each do |study_id|
              record_text(study_id, text)
            end
          end
        end
      end

      def record_text(study_id, text)
        exist = Groonga["Projects"][study_id][:search_fulltext]
        Groonga["Projects"][study_id][:search_fulltext] = [exist, text].join("\s")
      end

      def bulk_parse(type, pub_id_list)
        id_text = Hash.new("")
        xml_path = eutils_path(type, pub_id_list)
        nkgr = Nokogiri::XML(open(xml_path))
        id_text_pair = case type
                       when :pubmed
                         bulk_pubmed_parse(nkgr)
                       when :pmc
                         bulk_pmc_parse(nkgr)
                       end
        Hash[id_text_pair]
      rescue Errno::ENETUNREACH
        sleep 60
        retry
      end

      def bulk_pubmed_parse(nkgr)
        nkgr.css("PubmedArticle").map do |article|
          p = PubMedMetadataParser.new(article.to_xml)
          text = []
          text << p.journal_title
          text << p.article_title
          text << p.abstract
          text << p.affiliation
          text << p.authors.map{|n| n.values.compact }
          text << p.chemicals.map{|n| n[:name_of_substance] }
          text << p.mesh_terms.map{|n| n.values.compact }
          [p.pmid, clean_text(text.join("\s"))]
        end
      end

      def bulk_pmc_parse(pub_id_list)
        nkgr.css("article").map do |article|
          p = PMCMetadataParser.new(article.to_xml)
          ref_journal_list = p.ref_journal_list || []
          cited_by         = p.cited_by || []

          text = []
          text << ref_journal_list.map{|n| n.values }
          text << cited_by.map{|n| n.values }
          text << pmc_body_text(p)

          ["PMC" + p.pmcid, clean_text(text.join("\s"))]
        end
      end

      def pmc_body_text(pmc_parser)
        pmc_parser.body.compact.map do |section|
          if section.has_key?(:subsec)
            [section[:sec_title], section[:subsec].map{|subsec| subsec.values }]
          else
            section.values
          end
        end
      end

      def eutils_path(type, id_list)
        base = "http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?retmode=xml&"
        base + "db=#{type}&id=#{id_list.join(",")}"
      end

      def clean_text(text)
        text.delete("\t\n").gsub(/\s+/,"\s").chomp
      end
    end
  end
end
