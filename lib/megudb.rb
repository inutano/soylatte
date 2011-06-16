# -*- coding: utf-8 -*-

require "open-uri"
require "json"
require "nokogiri"
require "sqlite3"
require "pp"

def megumidono(specify_namamono)
# argument: URL.php to get JSON format output from mysql of sra.dbcls.jp, get Submission id - PMID pair and its related metadata
	
	jsondono = open(specify_namamono) { |n| JSON.load(n) }
	nakamidono = jsondono["ResultSet"]["Result"]
	
	set_info_pubmed = [] # set of entries
	nakamidono.each do |nakami|
		irumono = [] # individual entry: pmid, article_title, journal, date, sra_id, pm_abstract, pm_author (content array, not hash)
		nakami.each do |naka|
			unless ["vol", "issue", "page", "sra_title"].include?(naka[0])
				irumono.push(naka[1])
			end
		end
		
		pmid = irumono[0]
		url_pubmed = "http://www.ncbi.nlm.nih.gov/pubmed/#{pmid}"
		pubmed_html = Nokogiri::HTML(open(url_pubmed))
		pm_abstract = (pubmed_html/"div.abstr"/"p").inner_text
		pm_author = (pubmed_html/"div.auths").inner_text
		irumono.push(pm_abstract, pm_author)
		
		set_info_pubmed.push(irumono)
	end
	
	return set_info_pubmed
	
end

def parsexmldono(submission_id)
# argument: submission id,  get study/experiment/sample/run id and its description related to query submission id.
	begin
	
		sub_id_index = submission_id.slice(0,6)
		xmldono = "/Users/iNut/togofarm/xmldono/Submissions/#{sub_id_index}/#{submission_id}"
		
		sra_tree = []
		# set of metadata: [ [submission](0), [study](1), [[exp],[exp],..](2), [[sample],[sample],..](3), [[run],[run],..](4) ]
		
		# 1st: submission id
		sra_tree.push([submission_id])
		
		# 2nd: study id, study abstract, study description
		studydono = "#{xmldono}/#{submission_id}.study.xml"

		if !File.exist?(studydono)
			hako = ["no study metadata"]
			sra_tree.push(hako)
		else
			study_xml = Nokogiri::XML(File.read(studydono))
			study_id = (study_xml/"STUDY").attr("accession").to_s
			study_abst = (study_xml/"STUDY_ABSTRACT").inner_text.chomp
			study_desc = (study_xml/"STUDY_DESCRIPTION").inner_text.chomp 
			
			hako = []
			hako.push(study_id)
			
			if study_abst.empty?
				hako.push("no study abstract")
			else
				hako.push(study_abst)
			end
			
			if study_desc.empty?
				hako.push("no study description")
			else
				hako.push(study_desc)
			end
			
			sra_tree.push(hako)
		end
		
		# 3rd: array of exp set contains experiment id, experiment design, experiment library construction
		expdono = "#{xmldono}/#{submission_id}.experiment.xml"
		
		if !File.exist?(expdono)
			peko = ["no experiment metadata"]
			pekodono.push(peko)
			sra_tree.push(pekodono)
		else
			exp_xml = Nokogiri::XML(File.read(expdono))
			
			pekodono = []
			exp_xml.css("EXPERIMENT").each do |p|
			
				re_parse = Nokogiri::XML(p.to_xml)
				peko = []
				
				exp_id = (re_parse/"EXPERIMENT").attr("accession").to_s
				peko.push(exp_id)
				
				design = (re_parse/"DESIGN_DESCRIPTION").inner_text.chomp
				if design.empty?
					peko.push("no description for experiment design")
				else
					peko.push(design)
				end
				
				lib = (re_parse/"LIBRARY_CONSTRUCTION_PROTOCOL").inner_text.chomp
				if lib.empty?
					peko.push("no description for experiment library construction")
				else
					peko.push(lib)
				end
				
				sample_id = (re_parse/"SAMPLE_DESCRIPTOR").attr("accession").to_s
				peko.push(sample_id)
				
				pekodono.push(peko)
			end
		
			sra_tree.push(pekodono)
		end
		
		# 4th: array of sample set contains sample id, sample description, sample attribution[tag,value]
		sampledono = "#{xmldono}/#{submission_id}.sample.xml"
		
		if !File.exist?(sampledono)
			tako = ["no sample metadata"]
			takodono.push(tako)
			sra_tree.push(takodono)
		else
			sample_xml = Nokogiri::XML(File.read(sampledono))
			
			takodono = []
			sample_xml.css("SAMPLE").each do |t|
				
				re_parse = Nokogiri::XML(t.to_xml)
				tako = []
				
				sample_id = (re_parse/"SAMPLE").attr("accession").to_s
				tako.push(sample_id)
				
				desc = (re_parse/"DESCRIPTION").inner_text.chomp
				if desc.empty?
					tako.push("no sample description")
				else
					tako.push(desc)
				end
				
				if re_parse.css("SAMPLE_ATTRIBUTE").empty?
					tako.push(["no sample attributes"])
				else
					re_parse.css("SAMPLE_ATTRIBUTE").each do |atr|
						reparse_atr = Nokogiri::XML(atr.to_xml)
						attr_tag = (reparse_atr/"TAG").inner_text
						attr_val = (reparse_atr/"VALUE").inner_text
						tako.push([attr_tag,attr_val])
					end
				end
				
				takodono.push(tako)
			end
			
			sra_tree.push(takodono)	
		end
		
		# 6th: array of run set contains run id and exp id
		rundono = "#{xmldono}/#{submission_id}.run.xml"
		
		if !File.exist?(rundono)
			neko = ["no run metadata"]
			nekodono.push(neko)
			sra_tree.push(nekodono)
		else
			run_xml = Nokogiri::XML(File.read(rundono))
			
			nekodono = []
			run_xml.css("RUN").each do |n|
			
				re_parse = Nokogiri::XML(n.to_xml)
				neko = []
				
				run_id = (re_parse/"RUN").attr("accession").to_s
				neko.push(run_id)
				
				exp_id = (re_parse/"EXPERIMENT_REF").attr("accession").to_s
				neko.push(exp_id)
				
				nekodono.push(neko)
			end
			
			sra_tree.push(nekodono)
		end
		
		# push back everything!
		return sra_tree	
		
	rescue
	
		return "Oops! unknown error occurred!"
	end
end

def marge_array(meg)
# argument: json format pubmed metadata fixed by megumidono

	matomedono = []
	meg.each do |m|
		sub_id = m[4]
		metadata = parsexmldono(sub_id)
		m.delete_at(4)
		matome = metadata + m
		matomedono.push(matome)
	end

	return matomedono
	
end


if __FILE__ == $0
	# update SRAs publication data
	namamono = {"H_sapiens"=>"9606", "M_musculus"=>"10090", "A_thaliana"=>"3702", "All_species"=>"" }
#=begin
	namamono.each_pair do |nama,id|
		sra_url = "http://sra.dbcls.jp/cgi-bin/publication2.php?"
		namaurl = "#{sra_url}type=Transcriptome+Analysis&taxon_id=#{id}"
		pubmedono = megumidono(namaurl)
		open("SRAs_json/#{nama}.json","w") { |f| JSON.dump(pubmedono, f) }
	end
#=end
	# result_set: [[sraid],[study],[[exp],[exp]..],[[sample],[sample]..],[[run],[run]..],pmid,article_title,journal,date,abstract,author]
	namamono.each_key do |nama|
		namadono = open("SRAs_json/#{nama}.json") { |f| JSON.load(f) }
		result = marge_array(namadono)
		open("ksrnk_json/#{nama}.json","w") { |f| JSON.dump(result, f) }
	end
end
