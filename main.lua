-- crab volleyball
-- a pico-8 game by cascade

-- game constants
local gravity = 0.2
local jump_power = 3.5
local move_speed = 1.5
local ball_gravity = 0.15
local ball_bounce = 0.8
local net_height = 30
local net_width = 2
local net_x = 64
local ground_y = 110
local score_to_win = 5

-- ai constants
local ai_reaction_time = 0.2  -- seconds before AI reacts
local ai_prediction_error = 5  -- pixels of error in prediction
local ai_difficulty = 2       -- 1=easy, 2=medium, 3=hard

-- game state
local game_state = "title" -- title, game, game_over
local p1_score = 0
local p2_score = 0
local winner = 0
local serve_direction = -1
local ball_last_hit_by = 0
local ai_timer = 0
local ai_target_x = 0
local last_hit_time = 0
local hit_flash = 0

-- menu animations
local title_wave = 0
local title_colors = {7, 12, 14, 15, 14, 12, 7}
local menu_ball = {x = 64, y = 40, dx = 0.7, dy = -1.5, radius = 2}
local menu_timer = 0
local menu_crabs = {
  {x = 30, y = 100, flip = false, jump = false, jump_timer = 0, color = 8},
  {x = 98, y = 100, flip = true, jump = false, jump_timer = 0, color = 11}
}

-- game visual effects
local wave_offset = 0
local ocean_wave_offset = 0
local particles = {}
local max_particles = 20
local clouds = {
  {x = 20, y = 15, w = 20, speed = 0.2},
  {x = 70, y = 25, w = 30, speed = 0.1},
  {x = 110, y = 10, w = 25, speed = 0.15}
}
local ocean_waves = {
  {offset = 0, y = 55, speed = 0.3, amplitude = 1.5, wavelength = 30},
  {offset = 0.3, y = 70, speed = 0.2, amplitude = 2, wavelength = 50},
  {offset = 0.7, y = 85, speed = 0.15, amplitude = 1, wavelength = 40}
}
local score_flash = 0
local score_flash_color = 7
local island = {
  x = 30,
  y = 70,
  w = 25,
  h = 12
}

-- sprites
local crab1_sprite = 1  -- red crab sprite index (first row in spritesheet)
local crab2_sprite = 17 -- blue crab sprite index (second row in spritesheet)
local ball_sprite = 33  -- ball sprite index (third row in spritesheet)

-- entities
local crab1 = {
  x = 32,
  y = ground_y,
  dx = 0,
  dy = 0,
  width = 8,
  height = 8,
  flipped = false,
  grounded = true,
  color = 8 -- red
}

local crab2 = {
  x = 96,
  y = ground_y,
  dx = 0,
  dy = 0,
  width = 8,
  height = 8,
  flipped = true,
  grounded = true,
  color = 11 -- purple
}

local ball = {
  x = 32,
  y = 80,
  dx = 0,
  dy = 0,
  radius = 2,
  served = false
}

-- initialize game
function _init()
  reset_game()
end

-- reset game state
function reset_game()
  p1_score = 0
  p2_score = 0
  reset_round()
end

-- reset round
function reset_round()
  -- reset crabs
  crab1.x = 32
  crab1.y = ground_y
  crab1.dx = 0
  crab1.dy = 0
  crab1.grounded = true
  
  crab2.x = 96
  crab2.y = ground_y
  crab2.dx = 0
  crab2.dy = 0
  crab2.grounded = true
  
  -- reset ball
  if serve_direction == -1 then
    ball.x = 32
  else
    ball.x = 96
  end
  ball.y = 80
  ball.dx = 0
  ball.dy = 0
  ball.served = false
  
  ball_last_hit_by = 0
end

-- update game
function _update()
  if game_state == "title" then
    update_title()
  elseif game_state == "game" then
    update_game()
  elseif game_state == "game_over" then
    update_game_over()
  end
end

-- update title screen
function update_title()
  -- animate title wave
  title_wave = (title_wave + 0.05) % 1
  
  -- animate menu ball
  menu_ball.x += menu_ball.dx
  menu_ball.y += menu_ball.dy
  menu_ball.dy += 0.1 -- gravity
  
  -- bounce off edges
  if menu_ball.x < 10 or menu_ball.x > 118 then
    menu_ball.dx = -menu_ball.dx
  end
  
  -- bounce off top
  if menu_ball.y < 20 then
    menu_ball.y = 20
    menu_ball.dy = -menu_ball.dy * 0.8
  end
  
  -- bounce off ground
  if menu_ball.y > 95 then
    menu_ball.y = 95
    menu_ball.dy = -2.5 - rnd(1)
    sfx(2)
    
    -- maybe trigger crab jump
    local crab_idx = flr(rnd(2)) + 1
    if not menu_crabs[crab_idx].jump then
      menu_crabs[crab_idx].jump = true
      menu_crabs[crab_idx].jump_timer = 0
    end
  end
  
  -- update crabs
  for i=1,2 do
    local crab = menu_crabs[i]
    if crab.jump then
      crab.jump_timer += 1
      if crab.jump_timer > 30 then
        crab.jump = false
      end
    end
  end
  
  -- increment menu timer for pulsing effects
  menu_timer += 1
  
  -- start game with z/x
  if btnp(4) or btnp(5) then
    game_state = "game"
    sfx(3)
  end
end

-- update game
function update_game()
  -- update game entities
  update_crab1()
  update_crab2_ai()
  update_ball()
  check_collisions()
  check_scoring()
  
  -- update visual effects
  update_particles()
  update_clouds()
  wave_offset = (wave_offset + 0.02) % 1
  ocean_wave_offset = (ocean_wave_offset + 0.005) % 1
  
  -- update ocean waves
  for i=1,#ocean_waves do
    local wave = ocean_waves[i]
    wave.offset = (wave.offset + wave.speed/100) % 1
  end
  
  -- update score flash effect
  if score_flash > 0 then
    score_flash -= 1
  end
end

-- update particles
function update_particles()
  -- update existing particles
  for i=#particles,1,-1 do
    local p = particles[i]
    p.x += p.dx
    p.y += p.dy
    p.life -= 1
    
    -- remove dead particles
    if p.life <= 0 then
      deli(particles, i)
    end
  end
  
  -- create splash particles when ball is near water
  if ball.served and ball.y > 100 and ball.y < 105 and ball.dy > 2 then
    create_splash(ball.x, 104, 5)
  end
end

-- update cloud positions
function update_clouds()
  for i=1,#clouds do
    local cloud = clouds[i]
    cloud.x -= cloud.speed
    if cloud.x < -cloud.w then
      cloud.x = 128 + rnd(20)
      cloud.y = 5 + rnd(20)
      cloud.w = 15 + rnd(20)
      cloud.speed = 0.1 + rnd(0.2)
    end
  end
end

-- create a splash effect
function create_splash(x, y, num)
  for i=1,num do
    add(particles, {
      x = x,
      y = y,
      dx = (rnd(2)-1) * 0.7,
      dy = -rnd(2),
      life = 10 + rnd(10),
      color = 12
    })
  end
  sfx(2)
end

-- create hit effect
function create_hit_effect(x, y)
  for i=1,8 do
    local angle = rnd(1)
    local speed = 0.5 + rnd(1)
    add(particles, {
      x = x,
      y = y,
      dx = cos(angle) * speed,
      dy = sin(angle) * speed,
      life = 5 + rnd(10),
      color = 7
    })
  end
end

-- update game over screen
function update_game_over()
  if btnp(4) or btnp(5) then
    reset_game()
    game_state = "game"
  end
end

-- update crab 1 (player 1)
function update_crab1()
  -- horizontal movement
  if btn(0) then -- left
    crab1.dx = -move_speed
    crab1.flipped = true
  elseif btn(1) then -- right
    crab1.dx = move_speed
    crab1.flipped = false
  else
    crab1.dx = 0
  end
  
  -- jumping (with Z or UP arrow)
  if crab1.grounded and (btn(4) or btn(2)) then
    crab1.dy = -jump_power
    crab1.grounded = false
    sfx(0) -- jump sound
  end
  
  -- serving
  if not ball.served and ball_last_hit_by != 2 and btn(5) then
    ball.dx = 2
    ball.dy = -3
    ball.served = true
    sfx(1) -- serve sound
  end
  
  -- apply physics
  apply_physics(crab1)
  
  -- constrain to left side
  if crab1.x < 0 then crab1.x = 0 end
  if crab1.x > net_x - crab1.width then crab1.x = net_x - crab1.width end
end

-- update crab 2 (player 2)
function update_crab2()
  -- horizontal movement
  if btn(2) then -- left
    crab2.dx = -move_speed
    crab2.flipped = true
  elseif btn(3) then -- right
    crab2.dx = move_speed
    crab2.flipped = false
  else
    crab2.dx = 0
  end
  
  -- jumping
  if crab2.grounded and btn(5) then
    crab2.dy = -jump_power
    crab2.grounded = false
  end
  
  -- serving
  if not ball.served and ball_last_hit_by != 1 and btn(5) then
    ball.dx = -2
    ball.dy = -3
    ball.served = true
  end
  
  -- apply physics
  apply_physics(crab2)
  
  -- constrain to right side
  if crab2.x < net_x + net_width then crab2.x = net_x + net_width end
  if crab2.x > 128 - crab2.width then crab2.x = 128 - crab2.width end
end

-- update crab 2 AI
function update_crab2_ai()
  -- AI decision making
  ai_timer = max(0, ai_timer - 1/30)  -- decrement timer (30fps)
  
  -- only make decisions when timer is at 0
  if ai_timer <= 0 then
    ai_timer = ai_reaction_time  -- reset timer
    
    -- decide what to do based on ball position and state
    if ball.served then
      if ball.x > net_x then  -- ball is on AI's side
        -- predict where ball will land
        local predicted_x = predict_ball_landing()
        
        -- add some randomness based on difficulty
        predicted_x += (rnd(ai_prediction_error*2) - ai_prediction_error) / ai_difficulty
        
        -- set target position
        ai_target_x = mid(net_x + net_width + 5, predicted_x, 120 - crab2.width)
      else
        -- if ball is on player's side, move to a ready position
        ai_target_x = 96
      end
    else
      -- if ball is not served and it's AI's turn to serve
      if ball_last_hit_by != 1 then
        -- serve the ball after a short delay
        if t() - last_hit_time > 1.0 then
          ball.dx = -2 - rnd(1)  -- add some randomness
          ball.dy = -3 - rnd(1)  -- add some randomness
          ball.served = true
          sfx(1) -- serve sound
        end
      else
        -- get in position to receive
        ai_target_x = 96
      end
    end
  end
  
  -- move toward target position
  if crab2.x < ai_target_x - 2 then
    crab2.dx = move_speed
    crab2.flipped = false
  elseif crab2.x > ai_target_x + 2 then
    crab2.dx = -move_speed
    crab2.flipped = true
  else
    crab2.dx = 0
  end
  
  -- jump if ball is coming down and close
  if ball.served and ball.x > net_x and ball.dy > 0 and
     abs(ball.x - crab2.x) < 15 and ball.y < crab2.y and
     ball.y > crab2.y - 40 and crab2.grounded then
    crab2.dy = -jump_power
    crab2.grounded = false
    sfx(0) -- jump sound
  end
  
  -- apply physics
  apply_physics(crab2)
  
  -- constrain to right side
  if crab2.x < net_x + net_width then crab2.x = net_x + net_width end
  if crab2.x > 128 - crab2.width then crab2.x = 128 - crab2.width end
end

-- predict where the ball will land
function predict_ball_landing()
  local pred_x = ball.x
  local pred_y = ball.y
  local pred_dx = ball.dx
  local pred_dy = ball.dy
  
  -- simulate ball physics until it reaches ground level
  while pred_y < ground_y do
    pred_dy += ball_gravity
    pred_x += pred_dx
    pred_y += pred_dy
    
    -- bounce off walls
    if pred_x < ball.radius or pred_x > 128 - ball.radius then
      pred_dx = -pred_dx * ball_bounce
    end
    
    -- bounce off net
    if pred_x + ball.radius > net_x and pred_x - ball.radius < net_x + net_width and pred_y + ball.radius > 128 - net_height then
      pred_dx = -pred_dx * ball_bounce
    end
  end
  
  return pred_x
end

-- update ball
function update_ball()
  if ball.served then
    -- apply gravity
    ball.dy += ball_gravity
    
    -- update position
    ball.x += ball.dx
    ball.y += ball.dy
    
    -- bounce off walls with improved collision
    if ball.x < ball.radius then
      ball.x = ball.radius
      ball.dx = abs(ball.dx) * ball_bounce
      sfx(2) -- wall bounce sound
    end
    
    if ball.x > 128 - ball.radius then
      ball.x = 128 - ball.radius
      ball.dx = -abs(ball.dx) * ball_bounce
      sfx(2) -- wall bounce sound
    end
    
    -- bounce off ceiling
    if ball.y < ball.radius then
      ball.y = ball.radius
      ball.dy = abs(ball.dy) * ball_bounce
      sfx(2) -- ceiling bounce sound
    end
    
    -- bounce off net with improved collision
    if ball.x + ball.radius > net_x - 1 and 
       ball.x - ball.radius < net_x + net_width + 1 and 
       ball.y + ball.radius > 128 - net_height then
      
      -- determine which side of the net the ball hit
      if ball.dx > 0 then
        ball.x = net_x - ball.radius - 1
      else
        ball.x = net_x + net_width + ball.radius + 1
      end
      
      -- reverse horizontal direction and apply bounce
      ball.dx = -ball.dx * ball_bounce
      sfx(2) -- net bounce sound
    end
  else
    -- position ball above serving crab
    if serve_direction == -1 then
      ball.x = crab1.x + 4
      ball.y = crab1.y - 10
    else
      ball.x = crab2.x + 4
      ball.y = crab2.y - 10
    end
  end
end

-- apply physics to entity
function apply_physics(entity)
  -- apply gravity
  if not entity.grounded then
    entity.dy += gravity
  end
  
  -- update position
  entity.x += entity.dx
  entity.y += entity.dy
  
  -- check ground collision
  if entity.y > ground_y then
    entity.y = ground_y
    entity.dy = 0
    entity.grounded = true
  else
    entity.grounded = false
  end
end

-- check collisions
function check_collisions()
  -- check crab1 and ball collision with improved detection
  if ball.served and check_crab_ball_collision(crab1, ball) then
    -- handle collision with crab1
    handle_crab_ball_collision(crab1, ball, 1)
  end
  
  -- check crab2 and ball collision with improved detection
  if ball.served and check_crab_ball_collision(crab2, ball) then
    -- handle collision with crab2
    handle_crab_ball_collision(crab2, ball, 2)
  end
end

-- improved collision detection between crab and ball
function check_crab_ball_collision(crab, ball)
  -- use a much larger collision area for very forgiving hit detection
  local expanded_radius = ball.radius * 2.5
  local expanded_height = 4 -- additional pixels above crab for collision
  
  -- check if ball is within expanded crab hitbox
  return ball.x + expanded_radius > crab.x and 
         ball.x - expanded_radius < crab.x + crab.width and
         ball.y + expanded_radius > crab.y - expanded_height and
         ball.y - expanded_radius < crab.y + crab.height
end

-- handle collision between crab and ball
function handle_crab_ball_collision(crab, ball, crab_id)
  -- prevent multiple collisions in the same frame
  if ball_last_hit_by == crab_id then
    -- only allow a new hit if the ball has moved away and is now coming back
    if (crab_id == 1 and ball.dx < 0) or (crab_id == 2 and ball.dx > 0) then
      return
    end
    
    -- also prevent too frequent hits (within 10 frames)
    if t() - last_hit_time < 0.3 then
      return
    end
  end
  
  -- bounce ball off crab with improved physics
  ball.dy = -jump_power * 0.9
  
  -- adjust horizontal direction based on where ball hit crab
  local hit_pos = (ball.x - crab.x) / crab.width
  ball.dx = (hit_pos - 0.5) * 5
  
  -- add some of crab's momentum
  ball.dx += crab.dx * 1.2
  
  -- ensure minimum horizontal speed
  if abs(ball.dx) < 1.0 then
    ball.dx = crab_id == 1 and 1.0 or -1.0
  end
  
  -- track who hit it last
  ball_last_hit_by = crab_id
  last_hit_time = t()
  
  -- play sound
  sfx(0)
  
  -- visual feedback
  hit_flash = 5
  create_hit_effect(ball.x, ball.y)
end

-- check scoring
function check_scoring()
  -- ball hit ground
  if ball.y > ground_y then
    -- determine who scored
    if ball.x < net_x then
      -- player 2 scored
      p2_score += 1
      serve_direction = -1
      sfx(3) -- score sound
      last_hit_time = t() -- reset timer for AI serve delay
      score_flash = 30
      score_flash_color = 12
      
      -- create splash effect
      create_splash(ball.x, ground_y, 10)
    else
      -- player 1 scored
      p1_score += 1
      serve_direction = 1
      sfx(3) -- score sound
      last_hit_time = t() -- reset timer for AI serve delay
      score_flash = 30
      score_flash_color = 8
      
      -- create splash effect
      create_splash(ball.x, ground_y, 10)
    end
    
    -- check for game over
    if p1_score >= score_to_win then
      winner = 1
      game_state = "game_over"
    elseif p2_score >= score_to_win then
      winner = 2
      game_state = "game_over"
    else
      reset_round()
    end
  end
  
  -- prevent ball from getting stuck
  if ball.served and (ball.y < -20 or ball.y > ground_y + 20 or
     ball.x < -20 or ball.x > 148) then
    -- ball went out of bounds, reset it
    reset_round()
    last_hit_time = t() -- reset timer for AI serve delay
  end
end

-- draw game
function _draw()
  cls(1) -- dark blue background
  
  if game_state == "title" then
    draw_title()
  elseif game_state == "game" or game_state == "game_over" then
    draw_game()
    
    if game_state == "game_over" then
      draw_game_over()
    end
  end
end

-- draw title screen
function draw_title()
  -- background
  cls(1) -- dark blue background
  
  -- draw sand
  rectfill(0, 105, 127, 127, 10)
  
  -- draw sun
  circfill(100, 20, 8, 10)
  circfill(100, 20, 6, 9)
  circfill(100, 20, 4, 10)
  
  -- draw waves
  for i=0,8 do
    local wave_y = 104 + sin((i/8) + title_wave) * 2
    line(i*16, wave_y, i*16+12, wave_y, 12)
  end
  
  -- animated title with wave effect
  local title = "CRAB VOLLEYBALL"
  for i=1,#title do
    local char = sub(title, i, i)
    local x = 14 + i * 6
    local y = 35 + sin((i/5) + title_wave*2) * 3  -- moved down from 25 to 35
    local color_idx = ((i+flr(title_wave*10)) % #title_colors) + 1
    print(char, x, y, title_colors[color_idx])
  end
  
  -- draw net
  line(64, 105, 64, 85, 7)
  
  -- draw animated ball
  circfill(menu_ball.x, menu_ball.y, menu_ball.radius, 7)
  
  -- draw animated crabs
  for i=1,2 do
    local crab = menu_crabs[i]
    local y_offset = 0
    if crab.jump then
      y_offset = -sin(crab.jump_timer/30) * 20
    end
    draw_crab_shape(crab.x, crab.y + y_offset, crab.color, crab.flip)
  end
  
  -- controls box
  rectfill(18, 58, 110, 92, 0)
  rect(18, 58, 110, 92, 7)
  
  -- controls text
  print("player vs ai", 45, 60, 12)
  print("controls:", 45, 68, 7)
  print("⬅️➡️: move", 35, 76, 8)
  print("⬆️/z: jump", 35, 84, 8)
  
  -- pulsing start text
  local pulse = 7 + abs(sin(menu_timer/30)) * 8
  print("press z or x to start", 20, 110, pulse)
end

-- draw game
function draw_game()
  -- light blue sky background
  cls(12)
  
  -- draw clouds
  for i=1,#clouds do
    local cloud = clouds[i]
    draw_cloud(cloud.x, cloud.y, cloud.w)
  end
  
  -- draw sun
  circfill(100, 20, 8, 10)
  circfill(100, 20, 6, 9)
  circfill(100, 20, 4, 10)
  
  -- draw island in the background
  draw_island(island.x, island.y, island.w, island.h)
  
  -- draw ocean (solid dark blue)
  rectfill(0, 40, 127, ground_y-1, 1)
  
  -- draw lighter blue at top of ocean
  rectfill(0, 40, 127, 50, 12)
  
  -- draw rolling ocean waves
  for i=1,#ocean_waves do
    local wave = ocean_waves[i]
    local wave_y = wave.y
    
    -- prepare points for the wave line
    local points = {}
    for x=0,127 do
      -- calculate wave height using sine function with offset
      local wave_phase = (x/wave.wavelength) + wave.offset
      local y = wave_y + sin(wave_phase) * wave.amplitude
      points[x] = y
    end
    
    -- draw the wave line
    for x=0,126 do
      line(x, points[x], x+1, points[x+1], 12)
    end
    
    -- add some highlights (lighter blue)
    for x=0,127,4 do
      local wave_phase = (x/wave.wavelength) + wave.offset
      -- add highlights at wave peaks
      if sin(wave_phase) > 0.7 then
        pset(x, points[x]-1, 7) -- white highlight
      end
    end
  end
  
  -- draw waves at shoreline
  for i=0,8 do
    local wave_y = ground_y - 1 + sin((i/8) + wave_offset) * 2
    line(i*16, wave_y, i*16+12, wave_y, 7)
  end
  
  -- draw beach (sand) - solid color with no texture
  rectfill(0, ground_y, 127, 127, 10)
  
  -- draw net with shadow
  rectfill(net_x-1, 128 - net_height, net_x + net_width, 127, 5) -- shadow
  rectfill(net_x, 128 - net_height, net_x + net_width - 1, 127, 7) -- net
  
  -- draw net lines
  for y=128-net_height,127,4 do
    line(net_x, y, net_x+net_width-1, y, 6)
  end
  
  -- draw shadows under crabs
  fillp(0b1010010110100101)
  circfill(crab1.x + 4, ground_y + 1, 4, 5)
  circfill(crab2.x + 4, ground_y + 1, 4, 5)
  fillp()
  
  -- draw crabs with improved visuals
  draw_crab_shape(crab1.x, crab1.y, crab1.color, crab1.flipped)
  draw_crab_shape(crab2.x, crab2.y, crab2.color, crab2.flipped)
  
  -- draw particles
  for i=1,#particles do
    local p = particles[i]
    pset(p.x, p.y, p.color)
  end
  
  -- draw ball with hit flash effect and shadow
  fillp(0b1010010110100101)
  circfill(ball.x, ball.y + 2, ball.radius, 5)
  fillp()
  
  if hit_flash > 0 then
    circfill(ball.x, ball.y, ball.radius + hit_flash/2, 7)
    hit_flash -= 1
  else
    circfill(ball.x, ball.y, ball.radius, 7)
  end
  
  -- draw score with flash effect
  if score_flash > 0 then
    local flash_size = score_flash / 3
    circfill(64, 10, 10 + flash_size, score_flash_color)
  end
  
  -- draw score with shadow
  print(p1_score, 59, 6, 5) -- shadow
  print(p1_score, 58, 5, 8)
  print("-", 65, 6, 5) -- shadow
  print("-", 64, 5, 7)
  print(p2_score, 71, 6, 5) -- shadow
  print(p2_score, 70, 5, 11) -- purple score for AI
end

-- draw a cloud
function draw_cloud(x, y, w)
  -- Use color 7 (white) for clouds
  circfill(x, y, w/2, 7)      -- pure white cloud
  circfill(x+w/2, y, w/3, 7)  -- pure white cloud
  circfill(x-w/3, y+w/6, w/3, 7) -- pure white cloud
  circfill(x+w/4, y+w/4, w/4, 7) -- pure white cloud
end

-- draw a small island
function draw_island(x, y, w, h)
  -- island base
  fillp(0b0101101001011010.1)
  circfill(x, y, w/2, 3)
  rectfill(x-w/2, y-h/2, x+w/2, y, 3)
  fillp()
  
  -- island top (sand)
  circfill(x, y-h/3, w/3, 10)
  
  -- palm tree trunk
  line(x, y-h/3, x, y-h-2, 4)
  
  -- palm tree leaves
  for i=0,3 do
    local angle = i/4
    local lx = x + cos(angle) * 3
    local ly = y-h-2 + sin(angle) * 2
    line(x, y-h-2, lx, ly-2, 3)
  end
end

-- draw game over screen
function draw_game_over()
  -- semi-transparent overlay
  rectfill(20, 40, 108, 80, 0)
  rect(20, 40, 108, 80, 7)
  
  -- game over text
  print("game over", 45, 50, 7)
  
  if winner == 1 then
    print("you win!", 45, 60, 8)
  else
    print("ai wins!", 45, 60, 12)
  end
  
  print("press z or x to restart", 20, 70, 7)
end

-- draw a crab shape with primitives
function draw_crab_shape(x, y, color, flipped)
  -- Draw crab body
  circfill(x+4, y+4, 4, color)
  
  -- Draw crab claws
  if flipped then
    circfill(x+7, y+2, 2, color)
    circfill(x+1, y+2, 2, color)
  else
    circfill(x+1, y+2, 2, color)
    circfill(x+7, y+2, 2, color)
  end
  
  -- Draw crab legs
  if flipped then
    line(x+7, y+5, x+9, y+7, color)
    line(x+6, y+6, x+8, y+8, color)
    line(x+2, y+6, x, y+8, color)
    line(x+1, y+5, x-1, y+7, color)
  else
    line(x+1, y+5, x-1, y+7, color)
    line(x+2, y+6, x, y+8, color)
    line(x+6, y+6, x+8, y+8, color)
    line(x+7, y+5, x+9, y+7, color)
  end
  
  -- Draw crab eyes
  if flipped then
    pset(x+6, y+2, 7)
    pset(x+2, y+2, 7)
  else
    pset(x+2, y+2, 7)
    pset(x+6, y+2, 7)
  end
end
