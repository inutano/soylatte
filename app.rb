# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"
require "json"
require "./lib/database"
require "./lib/project_report"
require "./lib/run_report"

def logging(query)
  logfile = YAML.load_file("./config.yaml")["logfile"]
  log = Time.now.to_s + "\t" + query
  open(logfile,"a"){|f| f.puts(log) }
end

def query_filter(query_raw)
  query_raw
end

set :haml, :format => :html5

before do
  query = params[:search_query]
  logging(query) if query
end

get "/style.css" do
  sass :style
end

get "/soy_style.css" do
  sass :soy_style
end

get "/" do
  @instruments = Datbaase.instance.instruments
  @organisms = JSON.dump(Database.instance.scientific_names)
  haml :index
end

post "/filter" do
  @condition = { taxonid: params[:species],
                 study_type: params[:study_type],
                 instrument: params[:platform] }
  @total_number = Database.instance.size
  @result = Database.instance.filter(@condition)
  haml :filter
end

post "/search" do
  query_raw = params[:search_query]
  @query = query_filter(query_raw)
  
  @result = Database.instance.search_fulltext(@query)
  if @result
    haml :search
  else
    haml :not_found
  end
end

get %r{/view/((S|E|D)RP\d{6})} do |id, db|
  @report = ProjectReport.new(id, "./config.yaml").report
  haml :view_project
end

get %r{/data/((S|E|D)R(P|R)\d{6})?type=(.+)retmode=(.+)} do |id, db, idtype, dtype, retmode|
  puts [id, db, idtype, dtype, retmode]
  when idtype
  case "P"
    report = ProjectReport.new(id, "./config.yaml").report
    when dtype
    case "run"
      run_table = report[:run_table]
      when retmode
      case "tsv"
        run_table.map{|n| n.values.join("\t") }.join("\n")
      case "json"
        JSON.dump(run_table.map{|n| n.values })
      else
        :not_found
      end
    case "sample"
      sample_table = report[:sample_table]
      when retmode
      case "tsv"
        sample_table.map{|n| n.values.join("\t") }.join("\n")
      case "json"
        JSON.dump(sample_table.map{|n| n.values })
      else
        :not_found
      end
    else
      haml :not_found
    end
  #case "R"
  else
    haml :not_found
  end
end

get %r{/view/((S|E|D)RR\d{6}(|_1|_2))} do |id, db, read|
  RunReport.load_files("./config.yaml")
  run_report = RunReport.new(id)
  if run_report
    @report = run_report.report
    haml :view_run
  else
    haml :not_found
  end
end

get %r{/fastqc/img/((S|E|D)RR\d{6}(|_1|_2))/(\w+)$} do |fname, db, read, img_fname|
  qc_path = YAML.load_file("./config.yaml")["fqc_path"]
  pfx = fname.slice(0,6)
  id = fname.slice(0,9)
  img_path = File.join(qc_path, pfx, id, "#{fname}_fastqc/Images/#{img_fname}.png")
  send_file img_path
end

not_found do
  haml :not_found
end
