require 'sinatra'
require './app/move_calculator.rb'

$stdout.sync = true

configure do
  set :port, 8080
  set :bind, '0.0.0.0'
end

get '/' do
  'Let the battle begin! v.1.2'
end

post '/' do
  log_message("Move", MoveCalculator.new(JSON.parse(request.body.read)).process)
end

def log_message(description, message)
  puts "#{description}: #{message}"
  message
end
