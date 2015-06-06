# :)

require 'pry-byebug'

PROJ_ROOT = File.expand_path(__dir__)
NUM_OF_PARALLEL = 24

Dir["#{PROJ_ROOT}/lib/tasks/**/*.rake"].each do |path|
  load path
end

namespace :soylatte do
  desc "trigger fetching metadata and configuration"
  task :init => [ :fetch, :config ] do
    puts "Heads up: you need to sync fastqc directory before deploy application."
    puts "soylatte:init done."
  end
  
  desc "create db and load data"
  task :up => [ :create_db, :load_data ]
  
  task :fetch do
    Rake::Task["soylatte:fetch"].invoke
  end
  
  task :config do
    Rake::Task["soylatte:config"].invoke
  end
  
  task :create_db do
    Rake::Task["soylatte:create_db"].invoke
  end
  
  task :load_data do
    Rake::Task["soylatte:load_data"].invoke
  end
  
  desc "erase all db files."
  task :down do
    puts "Erase all db files? Y/N"
    answer = STDIN.gets.chomp
    if answer == "Y"
      rm_r File.join(PROJ_ROOT, "db")
    elsif answer == "N"
      puts "canceled."
    else
      puts "what?"
    end
  end
end
