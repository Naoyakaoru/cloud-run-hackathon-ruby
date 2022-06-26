class MoveCalculator

  # strategy settings
  CALC_TWO = true
  ATTACK_STRONGERS = true
  PRIO_STRONGERS_WITHIN_ONE_MOVE = true

  ME_URL = "https://cloud-run-hackathon-ruby-s2t5k4s32a-uc.a.run.app".freeze

  TURN_LEFT_NEW_DIR = {
    "N" => "W",
    "S" => "E",
    "W" => "S",
    "E" => "N"
  }

  TURN_RIGHT_NEW_DIR = {
    "N" => "E",
    "S" => "W",
    "W" => "N",
    "E" => "S"
  }

  OPPOSITE_DIR = {
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

    # run away if hit and check if anyone could still hit
    return turn_and_run if was_hit? && could_be_hit?

    # if I am not hitting anyone score higher than me and anyone score higher than me is with one move, move to it and prepare to attack
    return approach(calculate_if_can_attack_in_one_move(find_stronger: true)[:prey_key]) if PRIO_STRONGERS_WITHIN_ONE_MOVE && (hitting_target_key && hitting_target["score"] < me["score"]) && potential_stronger_preys.any?

    return attack! if can_attack?

    # if can attack within 1 move, move (find smaller score)
    return approach(calculate_if_can_attack_in_one_move[:prey_key]) if calculate_if_can_attack_in_one_move[:can_attack]

    # if can attack within 2 move, move (find smaller score)
    return calculate_if_can_attack_in_two_moves[:move] if CALC_TWO && calculate_if_can_attack_in_two_moves[:can_approach]

    get_random
  end

  private

  def set_arena_status
    @arena_width, @arena_height = @request_body["arena"]["dims"]
    @me = @request_body["arena"]["state"][ME_URL]
  end

  def turn_and_run
    enemy_opposite_facings = potential_attackers.map { |_k, v| OPPOSITE_DIR[v["direction"]] }.uniq

    # if can move forward and no one if front is able to attack me, go forward
    # if no one in left is able to attack me, and there's route to run away, turn left first
    # if no one in right is able to attack me, and there's route to run away, turn right first

    # === someone in front / left / right able to hit, or there's no route to run way ===
    # find most empty route and run!
    # if no way to run, hit someone instead
    if can_move_forward? && !enemy_opposite_facings.include?(me["direction"])
      "F"
    elsif !enemy_opposite_facings.include?(turn_left) && can_move_forward?(turn_left)
      "L"
    elsif !enemy_opposite_facings.include?(turn_right) && can_move_forward?(turn_right)
      "R"
    elsif can_move_forward?
      "F"
    elsif can_move_forward?(turn_left)
      "L"
    elsif can_move_forward?(turn_right)
      "R"
    elsif calculate_if_can_attack_in_one_move[:can_attack]
      approach(calculate_if_can_attack_in_one_move[:prey_key])
    elsif can_attack?
      attack!
    else
      get_random
    end
  end

  def can_move_forward?(direction = me["direction"])
    new_xy = send("forward_#{direction.downcase}", me["x"], me["y"])
    [*0..(@arena_width - 1)].include?(new_xy[0]) &&
      [*0..(@arena_height - 1)].include?(new_xy[1]) &&
        !@request_body["arena"]["state"].map { |_k, v| [v["x"], v["y"]]}.include?(new_xy)
  end

  def could_be_hit?
    potential_attackers.any?
  end

  def was_hit?
    me["wasHit"]
  end

  def can_attack?
    current_preys.any?
  end

  def current_preys
    @_current_preys ||= @request_body["arena"]["state"].select do |k, v|
      could_attack(me["direction"], me["x"], me["y"], v["x"], v["y"])
    end
  end

  def potential_attackers
    @_potential_attackers ||= @request_body["arena"]["state"].select do |k, v|
      could_attack(v["direction"], v["x"], v["y"], me["x"], me["y"])
    end
  end

  def potential_stronger_preys
    @_potential_stronger_preys ||= potential_preys.select do |k, v|
      v["score"] >= me["score"]
    end
  end

  def calculate_if_can_attack_in_one_move(find_stronger: false)
    return { prey_key: potential_stronger_preys.max_by{|k, v| v["score"]}[0] } if find_stronger

    @_calculate_if_can_attack_in_one_move ||= begin
      {}.tap do |h|
        h[:can_attack] = potential_preys.any?
        h[:prey_key] = (ATTACK_STRONGERS ? potential_preys.max_by{|k, v| v["score"]}[0] : potential_preys.min_by{|k, v| v["score"]}[0]) if h[:can_attack]
      end
    end
  end

  def calculate_if_can_attack_in_two_moves
    @_calculate_if_can_attack_in_two_moves ||= begin
      forward_new_xy = send("forward_#{me["direction"].downcase}", me["x"], me["y"])

      move = if potential_preys(me["direction"], forward_new_xy[0], forward_new_xy[1]).any?
        "F"
      elsif potential_preys(TURN_LEFT_NEW_DIR[me["direction"]]).any?
        "L"
      elsif potential_preys(TURN_RIGHT_NEW_DIR[me["direction"]]).any?
        "R"
      end

      {}.tap do |h|
        h[:can_approach] = !move.nil?
        h[:move] = move if h[:can_approach]
      end
    end
  end

  def potential_preys(attacker_direction = me["direction"], attacker_x = me["x"], attacker_y = me["y"])
    @request_body["arena"]["state"].select do |k, v|
      could_attack(TURN_LEFT_NEW_DIR[attacker_direction], attacker_x, attacker_y, v["x"], v["y"]) ||
        could_attack(TURN_RIGHT_NEW_DIR[attacker_direction], attacker_x, attacker_y, v["x"], v["y"]) ||
        could_attack(attacker_direction, attacker_x, attacker_y, *one_step_forward(me["direction"], v["x"], v["y"]))
    end
  end

  def hitting_target_key
    @_hitting_target_key ||= current_preys.min_by{ |k, v| distance_to_me(v["x"], v["y"]) }[0]
  end

  def hitting_target
    @_hitting_target ||= @request_body["arena"]["state"][hitting_target_key]
  end

  def distance_to_me(x, y)
    (x - me["x"]).abs + (y - me["y"]).abs
  end

  def log_message(description, message)
    puts "#{description}: #{message}"
  end

  def get_random
    ['F', 'L', 'R'].sample
  end

  def could_attack(attacker_direction, attacker_x, attacker_y, prey_x, prey_y)
    attacker_hit_ranges(attacker_direction, attacker_x, attacker_y).include?([prey_x, prey_y])
  end

  def attacker_hit_ranges(attacker_direction, attacker_x, attacker_y)
    case attacker_direction
    when "N"
      [[attacker_x, attacker_y - 1], [attacker_x, attacker_y - 2], [attacker_x, attacker_y - 3]]
    when "S"
      [[attacker_x, attacker_y + 1], [attacker_x, attacker_y + 2], [attacker_x, attacker_y + 3]]
    when "W"
      [[attacker_x - 1, attacker_y], [attacker_x - 2, attacker_y], [attacker_x - 3, attacker_y]]
    when "E"
      [[attacker_x + 1, attacker_y], [attacker_x + 2, attacker_y], [attacker_x + 3, attacker_y]]
    end
  end

  def attack!
    "T"
  end

  def one_step_forward(attacker_direction, prey_x, prey_y)
    range = case attacker_direction
    when "N"
      [prey_x, prey_y + 1]
    when "S"
      [prey_x, prey_y - 1]
    when "W"
      [prey_x + 1, prey_y]
    when "E"
      [prey_x - 1, prey_y]
    end
  end

  def approach(prey_key)
    prey_state = @request_body["arena"]["state"][prey_key]

    if could_attack(TURN_LEFT_NEW_DIR[me["direction"]], me["x"], me["y"], prey_state["x"], prey_state["y"])
      "L"
    elsif could_attack(TURN_RIGHT_NEW_DIR[me["direction"]], me["x"], me["y"], prey_state["x"], prey_state["y"])
      "R"
    else
      "F"
    end
  end

  def forward_n(x, y)
    [x, y - 1]
  end

  def forward_s(x, y)
    [x, y + 1]
  end

  def forward_e(x, y)
    [x + 1, y]
  end
 
  def forward_w(x, y)
    [x - 1, y]
  end

  def turn_left(original_direction = me["direction"])
    TURN_LEFT_NEW_DIR[original_direction]
  end

  def turn_right(original_direction = me["direction"])
    TURN_RIGHT_NEW_DIR[original_direction]
  end
end