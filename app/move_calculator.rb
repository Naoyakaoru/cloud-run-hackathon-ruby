class MoveCalculator

  ME_URL = "https://cloud-run-hackathon-ruby-s2t5k4s32a-uc.a.run.app".freeze

  # DIR => [L, R]
  ONE_MOVE_TURN = {
    "N" => ["W", "E"],
    "S" => ["E", "W"],
    "W" => ["S", "N"],
    "E" => ["N", "S"]
  }

  OPPOSITE = {
    "N" => "S",
    "S" => "N",
    "W" => "E",
    "E" => "W"
  }

  attr_accessor :me

  def initialize(request_body)
    @request_body = request_body
  end

  def process
    log_message("Request Body", @request_body)

    set_arena_status
    log_message("My State", me)

    return turn_and_run if could_be_hit? && was_hit?
    return attack! if can_attack?

    # if can attack within 1 move, move (find smaller score)
    return approach(calculate_if_can_attack_in_one_move[:pray_key]) if calculate_if_can_attack_in_one_move[:can_attack]

    # if can attack within 2 move, move (find smaller score)
    #
    get_random
  end

  private

  def set_arena_status
    @arena_width, @arena_height = @request_body["arena"]["dims"]
    @me = @request_body["arena"]["state"][ME_URL]
  end

  def turn_and_run
    enemy_opposite_facings = potential_attackers.map { |_k, v| OPPOSITE[v["direction"]] }.uniq

    if (ONE_MOVE_TURN[me["direction"]] - enemy_opposite_facings).empty? || can_move_forward?
      "F"
    elsif (ONE_MOVE_TURN[me["direction"]] - enemy_opposite_facings).include?(ONE_MOVE_TURN[me["direction"]][0]) && can_move_forward?(turn_left)
      "L"
    else
      "R"
    end
  end

  def can_move_forward?(direction = me["direction"])
    new_xy = send(direction.downcase, me["x"], me["y"])
    [*0..(@arena_width - 1)].include?(new_xy[0]) &&
      [*0..(@arena_height - 1)].include?(new_xy[1]) &&
        !potential_attackers.map { |_k, v| [v["x"], v["y"]]}.include?(new_xy)
  end

  def could_be_hit?
    potential_attackers.any?
  end

  def was_hit?
    me["wasHit"]
  end

  def can_attack?
    @request_body["arena"]["state"].select do |k, v|
      could_attack(me["direction"], me["x"], me["y"], v["x"], v["y"])
    end.any?
  end

  def potential_attackers
    @_potential_attackers ||= @request_body["arena"]["state"].select do |k, v|
      could_attack(v["direction"], v["x"], v["y"], me["x"], me["y"])
    end
  end

  def calculate_if_can_attack_in_one_move
    @_calculate_if_can_attack_in_one_move ||= begin
      prays = @request_body["arena"]["state"].select do |k, v|
        could_attack(ONE_MOVE_TURN[me["direction"]][0], me["x"], me["y"], v["x"], v["y"]) ||
          could_attack(ONE_MOVE_TURN[me["direction"]][1], me["x"], me["y"], v["x"], v["y"]) ||
          could_attack(me["direction"], me["x"], me["y"], *one_step_forward(me["direction"], v["x"], v["y"]))
      end

      {}.tap do |h|
        h[:can_attack] = prays.any?
        h[:pray_key] = prays.min_by{|k, v| v["score"]}[0] if h[:can_attack]
      end
    end
  end

  # def calculate_if_can_attack_in_two_moves
  # end

  def log_message(description, message)
    puts "#{description}: #{message}"
  end

  def get_random
    ['F', 'L', 'R'].sample
  end

  def could_attack(attacker_direction, attacker_x, attacker_y, pray_x, pray_y)
    range = case attacker_direction
    when "N"
      [attacker_y - 1, attacker_y - 2, attacker_y - 3]
    when "S"
      [attacker_y + 1, attacker_y + 2, attacker_y + 3]
    when "W"
      [attacker_x - 1, attacker_x - 2, attacker_x - 3]
    when "E"
      [attacker_x + 1, attacker_x + 2, attacker_x + 3]
    end

    if ["N", "S"].include?(attacker_direction)
      pray_x == attacker_x && range.include?(pray_y)
    else
      pray_y == attacker_y && range.include?(pray_x)
    end
  end

  def attack!
    "T"
  end

  def one_step_forward(attacker_direction, pray_x, pray_y)
    range = case attacker_direction
    when "N"
      [pray_x, pray_y + 1]
    when "S"
      [pray_x, pray_y - 1]
    when "W"
      [pray_x + 1, pray_y]
    when "E"
      [pray_x - 1, pray_y]
    end
  end

  def approach(pray_key)
    pray_state = @request_body["arena"]["state"][pray_key]

    if could_attack(ONE_MOVE_TURN[me["direction"]][0], me["x"], me["y"], pray_state["x"], pray_state["y"])
      "L"
    elsif could_attack(ONE_MOVE_TURN[me["direction"]][1], me["x"], me["y"], pray_state["x"], pray_state["y"])
      "R"
    else
      "F"
    end
  end

  def n(x, y)
    [x, y - 1]
  end

  def s(x, y)
    [x, y + 1]
  end

  def e(x, y)
    [x + 1, y]
  end
 
  def w(x, y)
    [x - 1, y]
  end

  def turn_left(original_direction = me["direction"])
    ONE_MOVE_TURN[original_direction][0]
  end

  def turn_right(original_direction = me["direction"])
    ONE_MOVE_TURN[original_direction][1]
  end
end