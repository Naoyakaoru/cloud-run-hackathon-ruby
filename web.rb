require 'sinatra'
require './app/move_calculator.rb'
require 'pry'

$stdout.sync = true

configure do
  set :port, 8080
  set :bind, '0.0.0.0'
end

get '/' do
  'Let the battle begin! v.1.2'
end

post '/' do
  MoveCalculator.new(JSON.parse(request.body.read)).process
end
