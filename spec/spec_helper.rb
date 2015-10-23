dir = File.expand_path('../../lib',__FILE__)
$:.unshift dir unless $:.include? dir

ENV['RAILS_ENV'] ||= 'test'

require 'blacklight_eds'

RSpec.configure do |config|
  config.order = "random"
end
