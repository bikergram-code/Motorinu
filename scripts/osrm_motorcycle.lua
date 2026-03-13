-- Lightweight Motorcycle profile for Bikergram
-- Does NOT use WayHandlers (saves ~20GB RAM during extract)
-- Uses plain Lua tables instead of Sequence/Set for minimal memory footprint

api_version = 4

local highway_speeds = {
  motorway        = 70,   -- penalized: bikers avoid Autobahn
  motorway_link   = 40,
  trunk           = 75,
  trunk_link      = 38,
  primary         = 65,
  primary_link    = 30,
  secondary       = 65,   -- BOOSTED: scenic Landstrasse
  secondary_link  = 30,
  tertiary        = 55,   -- BOOSTED: scenic Landstrasse
  tertiary_link   = 25,
  unclassified    = 40,   -- BOOSTED: scenic backroads
  residential     = 25,
  living_street   = 10,
  service         = 15,
}

local surface_speeds = {
  asphalt = 0,    -- 0 = no limit
  concrete = 0,
  paved = 0,
  gravel = 30,
  unpaved = 25,
  ground = 20,
  dirt = 15,
  mud = 5,
  sand = 8,
  cobblestone = 25,
  sett = 35,
  paving_stones = 50,
  compacted = 60,
  fine_gravel = 50,
}

local access_whitelist = {
  yes = true, motorcar = true, motor_vehicle = true,
  vehicle = true, permissive = true, designated = true,
  hov = true, motorcycle = true,
}

local access_blacklist = {
  no = true, agricultural = true, forestry = true,
  emergency = true, psv = true, private = true,
  delivery = true,
}

local access_hierarchy = { "motorcycle", "motor_vehicle", "vehicle", "access" }
local restriction_tags = { "motorcycle", "motor_vehicle", "vehicle" }

function setup()
  return {
    properties = {
      max_speed_for_map_matching    = 180/3.6,
      weight_name                   = "routability",
      process_call_tagless_node     = false,
      u_turn_penalty                = 20,
      continue_straight_at_waypoint = true,
      use_turn_restrictions         = true,
      left_hand_driving             = false,
      traffic_light_penalty         = 2,
    },
    default_mode      = mode.driving,
    default_speed     = 50,
    side_road_multiplier  = 0.8,
    turn_penalty          = 7.5,
    turn_bias             = 1.075,
  }
end

function process_node(profile, node, result, relations)
  -- Check access tags on nodes
  for _, tag in ipairs(access_hierarchy) do
    local val = node:get_value_by_key(tag)
    if val then
      if access_blacklist[val] then
        result.barrier = true
      end
      break
    end
  end

  -- Handle barriers
  local barrier = node:get_value_by_key("barrier")
  if barrier then
    if barrier == "bollard" or barrier == "gate" or
       barrier == "lift_gate" or barrier == "swing_gate" then
      -- Check if motorcycle/vehicle access is explicitly allowed
      for _, tag in ipairs(access_hierarchy) do
        local val = node:get_value_by_key(tag)
        if val then
          if access_whitelist[val] then
            result.barrier = false
          else
            result.barrier = true
          end
          break
        end
      end
      -- No access tag found = assume barrier
      if not node:get_value_by_key("motorcycle") and
         not node:get_value_by_key("motor_vehicle") and
         not node:get_value_by_key("vehicle") and
         not node:get_value_by_key("access") then
        result.barrier = true
      end
    end
  end

  -- Traffic lights
  local highway = node:get_value_by_key("highway")
  if highway and highway == "traffic_signals" then
    result.traffic_lights = true
  end
end

function process_way(profile, way, result, relations)
  local highway = way:get_value_by_key("highway")

  -- Also handle ferries/routes
  local route = way:get_value_by_key("route")
  if route == "ferry" then
    result.forward_speed = 5
    result.backward_speed = 5
    result.forward_mode = mode.driving
    result.backward_mode = mode.driving
    result.name = way:get_value_by_key("name") or ""
    return
  end

  if not highway or highway == "" then
    return
  end

  -- Check access restrictions
  for _, tag in ipairs(access_hierarchy) do
    local val = way:get_value_by_key(tag)
    if val then
      if access_blacklist[val] then
        return  -- way is not accessible
      end
      break
    end
  end

  -- Get base speed for this highway type
  local speed = highway_speeds[highway]
  if not speed then
    return  -- unknown highway type, skip
  end

  -- Surface penalty
  local surface = way:get_value_by_key("surface")
  if surface then
    local surf_speed = surface_speeds[surface]
    if surf_speed and surf_speed > 0 then
      speed = math.min(speed, surf_speed)
    end
  end

  -- Maxspeed tag override
  local maxspeed = way:get_value_by_key("maxspeed")
  if maxspeed then
    local parsed = tonumber(maxspeed)
    if parsed and parsed > 0 then
      speed = math.min(speed, parsed)
    end
  end

  -- Oneway handling
  local oneway = way:get_value_by_key("oneway")
  if oneway == "-1" then
    result.forward_mode = mode.inaccessible
    result.forward_speed = 0
    result.backward_speed = speed
    result.backward_mode = mode.driving
  elseif oneway == "yes" or oneway == "1" or oneway == "true" then
    result.forward_speed = speed
    result.forward_mode = mode.driving
    result.backward_mode = mode.inaccessible
    result.backward_speed = 0
  else
    result.forward_speed = speed
    result.backward_speed = speed
    result.forward_mode = mode.driving
    result.backward_mode = mode.driving
  end

  -- Junction = roundabout implies oneway
  local junction = way:get_value_by_key("junction")
  if junction == "roundabout" or junction == "circular" then
    result.roundabout = true
    result.backward_mode = mode.inaccessible
    result.backward_speed = 0
  end

  -- Set name/ref
  result.name = way:get_value_by_key("name") or ""
  result.ref = way:get_value_by_key("ref") or ""

  -- Classes for avoid options (motorway, toll, tunnel)
  if highway == "motorway" or highway == "motorway_link" then
    result.forward_classes["motorway"] = true
    result.backward_classes["motorway"] = true
  end
  local toll = way:get_value_by_key("toll")
  if toll and (toll == "yes" or toll == "true") then
    result.forward_classes["toll"] = true
    result.backward_classes["toll"] = true
  end
  local tunnel = way:get_value_by_key("tunnel")
  if tunnel and (tunnel == "yes" or tunnel == "true") then
    result.forward_classes["tunnel"] = true
    result.backward_classes["tunnel"] = true
  end
end

function process_turn(profile, turn)
  if turn.is_u_turn then
    turn.duration = turn.duration + profile.properties.u_turn_penalty
    turn.weight = turn.weight + profile.properties.u_turn_penalty
  end

  if turn.has_traffic_light then
    turn.duration = turn.duration + profile.properties.traffic_light_penalty
  end

  if turn.number_of_roads > 2 or turn.source_mode ~= turn.target_mode or turn.is_u_turn then
    if turn.angle >= 0 and turn.angle < 60 then
      turn.duration = turn.duration + profile.turn_penalty / 2
    elseif turn.angle >= 60 and turn.angle <= 300 then
      turn.duration = turn.duration + profile.turn_penalty
    end
  end
end

return {
  setup = setup,
  process_way = process_way,
  process_node = process_node,
  process_turn = process_turn,
}
