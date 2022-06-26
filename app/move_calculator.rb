class MoveCalculator

  # strategy settings
  CALC_TWO = true
  ATTACK_STRONGERS = true

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

    return turn_and_run if could_be_hit? && was_hit?
    return attack! if can_attack?

    # if can attack within 1 move, move (find smaller score)
    return approach(calculate_if_can_attack_in_one_move[:prey_key]) if calculate_if_can_attack_in_one_move[:can_attack]

    # if can attack within 2 move, move (find smaller score)
    return calculate_if_can_attack_in_two_moves[:move] if CALC_TWO && calculate_if_can_attack_in_two_moves[:can_approach]

    get_random
  rescue => e
    log_message("ERROR", e)
    get_random
  end

  private

  def set_arena_status
    me_url = @request_body["_links"]["self"]["href"] || ME_URL
    @arena_width, @arena_height = @request_body["arena"]["dims"]
    @me = @request_body["arena"]["state"][me_url]
  end

  def turn_and_run
    enemy_opposite_facings = potential_attackers.map { |_k, v| OPPOSITE_DIR[v["direction"]] }.uniq

    if can_move_forward? && !enemy_opposite_facings.include?(me["direction"])
      "F"
    elsif !enemy_opposite_facings.include?(TURN_LEFT_NEW_DIR[me["direction"]]) && can_move_forward?(turn_left)
      "L"
    else
      "R"
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

  def get_random
    ['F', 'L', 'R'].sample
  end

  def could_attack(attacker_direction, attacker_x, attacker_y, prey_x, prey_y)
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
      prey_x == attacker_x && range.include?(prey_y)
    else
      prey_y == attacker_y && range.include?(prey_x)
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