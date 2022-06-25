require 'sinatra'

$stdout.sync = true

configure do
  set :port, 8080
  set :bind, '0.0.0.0'
end

get '/' do
  'Let the battle begin! v.1.1'
end

post '/' do
  me_url = "https://cloud-run-hackathon-ruby-s2t5k4s32a-uc.a.run.app"
  puts JSON.parse(request.body.read)

  moves = ['F', 'L', 'R']

  req_body = JSON.parse(request.body.read)
  arean_width, arean_height = req_body["arena"]["dims"]
  me_state = req_body["arena"]["state"][me_url]
  puts me_state
  me_x = me_state["x"]
  me_y = me_state["y"]

  dim = case me_state["direction"]
  when "N"
    axsis = "Y"
    [me_y - 1, me_y - 2, me_y - 3]
  when "S"
    axsis = "Y"
    [me_y + 1, me_y + 2, me_y + 3]
  when "W"
    axsis = "X"
    [me_x - 1, me_x - 2, me_x - 3]
  when "E"
    axsis = "X"
    [me_x + 1, me_x + 2, me_x + 3]
  end

  selected = req_body["arena"]["state"].select do |k, v|
    if axsis "Y"
      v["x"] == me_x && v["y"].in?(dim)
    else
      v["y"] == me_y && v["x"].in?(dim)
    end
  end

  puts selected
  if selected.any?
    "T"
  else
    moves.sample
  end
end
