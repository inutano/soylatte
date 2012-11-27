# -*- coding: utf-8 -*-

require "sinatra"
require "haml"
require "sass"

get %r{/$} do
  haml :index
end


