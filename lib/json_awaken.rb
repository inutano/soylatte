# -*- coding: utf-8 -*-

require "open-uri"
require "json"
require "nokogiri"
require "pp"

=begin	
def fix_json(taxon_id, study_type)
	sras_url = "http://sra.dbcls.jp/cgi-bin/publication2.php?"
	url_json = "#{sras_url}type=#{study_type}&taxon_id=#{taxon_id}"
	
	sotogawa = open(url_json) { |n| JSON.load(n) }
	nakamidono = sotogawa["ResultSet"]["Result"]
	
	pubmed_metadata = []
	nakamidono.each do |nakami|
		irumono = [] # array: pmid, article_title, journal, date, sra_id, then pm_abstract, pm_author
		nakami.each do |naka|
			if !["vol", "issue", "page", "sra_title"].include?(naka[0])
				irumono.push(naka[1])
			end
		end
		
		pmid = irumono[0]
		url_pubmed = "http://www.ncbi.nlm.nih.gov/pubmed/#{pmid}"
		pp url_pubmed
		pubmed_html = Nokogiri::HTML(open(url_pubmed))
		pm_abstract = (pubmed_html/"div.abstr"/"p").inner_text
		pm_author = (pubmed_html/"div.auths").inner_text
		irumono.push(pm_abstract, pm_author)
		
		pubmed_metadata.push(irumono)
	end
	
	return pubmed_metadata
end

def refresh_json # refresh json data from sra.dbcls.jp after fix data with fix_json
	organism = { "Hsapiens" => "9606", "Mmusculus" => "10090", "Athaliana" => "3702", "Allspecies" => "" }
	study_type = ["Transcriptome+Analysis"]
	
	organism.each do |name, id|
		study_type.each do |type|
			pubmed_metadata = fix_json(id, type) # method defined above
			
			type_unplus = type.gsub("+","")
			open("./SRAs_json_test/#{type_unplus}_#{name}.json","w") { |f| JSON.dump(pubmed_metadata, f) }
		end
	end
end
=end

class GetMetadata
	def initialize(sub_id)
		@sub_id = sub_id
		@sub_id_index = sub_id.slice(0,6)
		@xmldono = "/Users/iNut/togofarm/xmldono/Submissions/#{@sub_id_index}/#{@sub_id}"
	end
	
	def pubmed_info(json_fixed)
		db = open(json_fixed) { |f| JSON.load(f) }
		result = []
		db.each do |set|
			if @sub_id == set[4]
				result.push(set)
			end
		end
		
		if result.length == 1 # normally length == 1 but sometimes single SRA entry has multiple publication, like 1000genomes project
			return result.flatten
		else
			return result
		end
	end
	
	def study_info
	# return array of information. If xml doesn't exist, return nil
		path_db_study = "#{@xmldono}/#{@sub_id}.study.xml"
		
		if File.exist?(path_db_study)
			db = Nokogiri::XML(File.read(path_db_study))
			study_id = (db/"STUDY").attr("accession").to_s
			study_abst = (db/"STUDY_ABSTRACT").inner_text.chomp
			study_desc = (db/"STUDY_DESCRIPTION").inner_text.chomp
			
			if study_abst.empty?
				study_abst = "no study abstract"
			end
			if study_desc.empty?
				study_desc = "no study description"
			end
			
			return [study_id, study_abst, study_desc]
		end
	end
	
	def exp_info
	# same as study_info do
		path_db_sample = "#{@xmldono}/#{@sub_id}.experiment.xml"
		
		if File.exist?(path_db_sample)
			exp_result = []
			db = Nokogiri::XML(File.read(path_db_sample))
			db.css("EXPERIMENT").each do |exp|
				exp_xml = Nokogiri::XML(exp.to_xml)
				exp_id = (exp_xml/"EXPERIMENT").attr("accession").to_s
				design = (exp_xml/"DESIGN_DESCRIPTION").inner_text.chomp
				lib = (exp_xml/"LIBRARY_CONSTRUCTION_PROTOCOL").inner_text.chomp
				platform = (exp_xml/"INSTRUMENT_MODEL").inner_text
				space = (exp_xml/"SEQUENCE_SPACE").inner_text
				sample_id = (exp_xml/"SAMPLE_DESCRIPTOR").attr("accession").to_s
				
				
				# get run information
				path_db_run = "#{@xmldono}/#{@sub_id}.run.xml"
				if File.exist?(path_db_run)
					db = Nokogiri::XML(File.read(path_db_run))
					run_seq_run = []
					db.css("RUN").each do |run|
						run_xml = Nokogiri::XML(run.to_xml)
						run_id = (run_xml/"RUN").attr("accession").to_s
						exp_id_for_run = (run_xml/"EXPERIMENT_REF").attr("accession").to_s
						if exp_id == exp_id_for_run
							dra_run = open("http://trace.ddbj.nig.ac.jp/DRASearch/run?acc=#{run_id}").read
							spotnum = dra_run.scan(/spots<\/td><td><span id=\"number_of_spot\">(.*)<\/span><\/td>/).flatten.join("")
							basenum = dra_run.scan(/Number of bases<\/td><td>(.*)<\/td><\/tr>/).flatten.join("")
							read_length = basenum.gsub(",","").to_i / spotnum.gsub(",","").to_i
							run_seq_run.push([run_id, spotnum, basenum, read_length])
						end
					end
				end
				
				if design.empty?
					design = "no description for experiment design"
				end
				if lib.empty?
					lib = "no description for library construction"
				end
				if platform.empty?
					platform = "no platform information"
				end
				if space.empty?
					space = "no sequence space information"
				end
				if run_seq_run.empty?
					run_seq_run = "no sequence run information"
				end
				
				exp_result.push([exp_id, design, lib, platform, space, sample_id, run_seq_run])
			end
			
			return exp_result
		end
	end
	
	def sample_info
		path_db_sample = "#{@xmldono}/#{@sub_id}.sample.xml"
		if File.exist?(path_db_sample)
			sample_box = []
			db = Nokogiri::XML(File.read(path_db_sample))
			db.css("SAMPLE").each do |sample|
				sample_xml = Nokogiri::XML(sample.to_xml)
				sample_id = (sample_xml/"SAMPLE").attr("accession").to_s
				sample_desc = (sample_xml/"DESCRIPTION").inner_text.chomp
				
				sample_attr = []
				sample_xml.css("SAMPLE_ATTRIBUTE").each do |attr|
					attr_xml = Nokogiri::XML(attr.to_xml)
					attr_tag = (attr_xml/"TAG").inner_text
					attr_val = (attr_xml/"VALUE").inner_text
					sample_attr.push([attr_tag, attr_val])
				end
				
				if sample_desc.empty?
					sample_desc = "no sample description"
				end
				if sample_attr.empty?
					sample_attr = ["no attribution tag", "no attribution value"]
				end
				
				sample_box.push([sample_id, sample_desc, sample_attr])
			end
			
			return sample_box
		end
	end
end #end of class BuildDB


if __FILE__ == $0

#	to refresh json database on local server, uncomment the line below
#	refresh_json

	organism = { "Hsapiens" => "9606", "Mmusculus" => "10090", "Athaliana" => "3702", "Allspecies" => "" }
	study_type = ["Transcriptome+Analysis"]
	
	organism.each_key do |name|
		study_type.each do |type|
			content_db = []
			type_unplus = type.gsub("+","")
			path_db_json = "./SRAs_json_test/#{type_unplus}_#{name}.json"
			db = open(path_db_json){ |f| JSON.load(f) }
			db.each do |set|
				acc_id = set[4]
				
				meta = GetMetadata.new(acc_id)
				
				# each variant without pubmed can return nil by xml metadata absent
				section_pubmed = meta.pubmed_info(path_db_json)
				section_study = meta.study_info
				section_exp = meta.exp_info
				section_sample = meta.sample_info
				
				content_db.push([acc_id, section_pubmed, section_study, section_exp, section_sample])
			end
			pp content_db
			open("./ksrnk_json_test/#{type_unplus}_#{name}.json","w") { |f| JSON.dump(content_db, f) }
		end
	end
end
