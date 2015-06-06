# :)

require 'groonga'
require File.join(PROJ_ROOT, 'lib', 'repos', 'opPMC', 'publication_metadata_parser')

class SoylatteDB
  class Publication
    class << self
      include PublicationMetadataParser

      def load(db)
        establish_connection(db)
        load_pub(:pubmed)
        load_pub(:pmc)
      end

      def establish_connection(db)
        Groonga::Database.open(db)
      end
      
      def load_pub(type)
        projectdb = Groonga["Projects"]
        studydb   = Groonga["StudyIDs"]
        col_sym = "#{type}_id".intern
        
        subset = []
        studydb.each do |record|
          # eutils accept the request with multiple ids up to 100
          pub_id_list = subset.map{|r| r.send(col_sym) }.uniq.compact
          num_of_next_pubs = record.send(col_sym).size
          
          # request and parse or stock items
          if pub_id_list.size + num_of_next_pubs >= 100
            pub_id_text_pairs = bulk_parse(type, pub_id_list)
            pub_id_text_pairs.each_pair do |pub_id, text|
              study_id_list = subset.select{|r| r.send(col_sym) == pub_id }.map{|r| r["_key"] }.flatten
              study_id_list.each do |study_id|
                record_text(projectdb, study_id, text)
              end
            end
            subset = [] # reset subset array
            subset << record
          else
            subset << record
          end
        end
      end
      
      def record_text(projectdb, study_id, text)
        record = projectdb[study_id]
        if record
          exist = record[:search_fulltext]
          record[:search_fulltext] = [exist, text].join("\s")
        end
      end

      def bulk_parse(type, pub_id_list)
        id_text = Hash.new("")
        xml_path = eutils_path(type, pub_id_list)
        
        sleep 1
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

      def bulk_pmc_parse(nkgr)
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
