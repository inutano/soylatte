# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"
require "yaml"
require "json"
require "uri"

require "./lib/database.rb"

require "ap"

def logging(query)
  logfile = settings.config["logfile"]
  log = Time.now.to_s + "\t" + query
  open(logfile,"a"){|f| f.puts(log) }
end

def query_filter(query)
  size = query.size
  invalid_char = settings.config["invalid_char"]
  if size == 0
    ""
  elsif size > 140 || size < 2
    nil
  else
    valid_query = query.force_encoding("utf-8")
    invalid_char.each do |char|
      valid_query.gsub!(char, "")
    end
    valid_query
  end
end

set :haml, :format => :html5

configure do
  set :config, YAML.load_file("./config.yaml")
end

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
  m = Database.instance
  @instruments = m.instruments
  @species = JSON.dump(m.species)
  haml :index
end

post "/filter" do
  species = params[:species]
  study_type = params[:study_type]
  instrument = params[:platform]
  options = "species=#{species}&type=#{study_type}&instrument=#{instrument}"
  encoded = URI.encode(options)
  redirect to("/filter?#{encoded}")
end

get "/filter" do
  @species = params[:species]
  @type = params[:type]
  @instrument = params[:instrument]
  
  m = Database.instance
  @result = m.filter_result(@species, @type, @instrument)
  haml :filter
end

post "/search" do
  m = Database.instance
  @query = query_filter(params[:search_query])
  if !@query
    redirect to("/not_found")
  elsif @query =~ /^(S|E|D)R(A|P|X|R|S)\d{6}$/
    study_id = m.convert_to_study_id(@query)
    redirect to("/view/#{study_id}")
  else
    @result = m.search(@query,
                       species: params[:species],
                       type: params[:type],
                       instrument: params[:instrument])
    redirect to("/not_found") if @result.empty?
    haml :search
  end
end

get %r{/view/((S|E|D)RP\d{6})} do |id, db|
  m = Database.instance
  @report = m.project_report(id)
  haml :view_project
end

get %r{/data/((S|E|D)R(P|R)\d{6})} do |id, db, idtype|
  dtype = params[:type]
  retmode = params[:retmode]
  
  m = Database.instance
  result = m.data_retrieve(id, :retmode => retmode, :dtype => dtype)
  redirect to ("/not_found") if result
  result
end

get %r{/view/((S|E|D)RR\d{6}(|_1|_2))} do |id, db, read|
  m = Database.instance
  @report = m.run_report(id)
  redirect to("/not_found") if !@report
  haml :view_run
end

get %r{/fastqc/img/((S|E|D)RR\d{6}(|_1|_2))/(\w+)$} do |fname, db, read, img_fname|
  qc_path = settings.config["fqc_path"]
  pfx = fname.slice(0,6)
  id = fname.slice(0,9)
  img_path = File.join(qc_path, pfx, id, "#{fname}_fastqc/Images/#{img_fname}.png")
  send_file img_path
end

not_found do
  m = Database.instance
  @instruments = m.instruments
  @species = JSON.dump(m.species)
  haml :not_found
end
