local json = require("dkjson")

local settings_path = assert(arg[1], "missing settings json path")
local file = assert(io.open(settings_path, "r"))
local settings = assert(json.decode(file:read("*a")))
file:close()

local function is_array(value)
  if type(value) ~= "table" then
    return false
  end

  local count = 0
  for key, _ in pairs(value) do
    if type(key) ~= "number" then
      return false
    end
    count = count + 1
  end

  return count == #value
end

local function sorted_keys(tbl)
  local keys = {}
  for key, _ in pairs(tbl) do
    table.insert(keys, key)
  end
  table.sort(keys)
  return keys
end

local function split(input, separator)
  local parts = {}
  local pattern = "([^" .. separator .. "]+)"
  for part in string.gmatch(input, pattern) do
    table.insert(parts, (part:gsub("^%s+", ""):gsub("%s+$", "")))
  end
  return parts
end

local function split_limit(input, separator, limit)
  local parts = {}
  local rest = input

  for _ = 1, limit - 1 do
    local start_at, end_at = string.find(rest, separator, 1, true)
    if not start_at then
      break
    end

    table.insert(parts, (string.sub(rest, 1, start_at - 1):gsub("^%s+", ""):gsub("%s+$", "")))
    rest = string.sub(rest, end_at + 1)
  end

  table.insert(parts, (rest:gsub("^%s+", ""):gsub("%s+$", "")))
  return parts
end

local function lua_value(value, indent)
  indent = indent or 0
  local pad = string.rep(" ", indent)
  local next_pad = string.rep(" ", indent + 2)

  if type(value) == "string" then
    return string.format("%q", value)
  elseif type(value) == "boolean" or type(value) == "number" then
    return tostring(value)
  elseif type(value) ~= "table" then
    return "nil"
  end

  local lines = { "{" }
  if is_array(value) then
    for _, item in ipairs(value) do
      table.insert(lines, next_pad .. lua_value(item, indent + 2) .. ",")
    end
  else
    for _, key in ipairs(sorted_keys(value)) do
      local lua_key = string.match(key, "^[%a_][%w_]*$") and key or "[" .. string.format("%q", key) .. "]"
      table.insert(lines, next_pad .. lua_key .. " = " .. lua_value(value[key], indent + 2) .. ",")
    end
  end

  table.insert(lines, pad .. "}")
  return table.concat(lines, "\n")
end

local function boolish(value)
  return value == true or value == 1 or value == "1" or value == "true"
end

local function set_path(root, dotted_key, value)
  if dotted_key == "col.active_border" and type(value) == "string" then
    local colors = {}
    local angle = nil
    for token in string.gmatch(value, "%S+") do
      local degrees = string.match(token, "^(%d+)deg$")
      if degrees then
        angle = tonumber(degrees)
      else
        table.insert(colors, token)
      end
    end
    value = { colors = colors, angle = angle }
  end

  local parts = split(dotted_key, ".")
  local cursor = root
  for i = 1, #parts - 1 do
    local part = parts[i]
    cursor[part] = cursor[part] or {}
    cursor = cursor[part]
  end
  cursor[parts[#parts]] = value
end

local function normalize_section(section)
  local normalized = {}
  for key, value in pairs(section or {}) do
    set_path(normalized, key, value)
  end
  return normalized
end

local function emit_config()
  local section_names = {
    "animations",
    "cursor",
    "decoration",
    "dwindle",
    "ecosystem",
    "general",
    "input",
    "master",
    "misc",
  }
  local config = {}

  for _, name in ipairs(section_names) do
    if type(settings[name]) == "table" and not is_array(settings[name]) then
      config[name] = normalize_section(settings[name])
    end
  end

  if next(config) then
    print("hl.config(" .. lua_value(config) .. ")")
  end
end

local function emit_monitors()
  for _, monitor in ipairs(settings.monitor or {}) do
    local parts = split(monitor, ",")
    local spec = {
      output = parts[1],
      mode = parts[2],
      position = parts[3],
      scale = tonumber(parts[4]) or parts[4],
    }

    local i = 5
    while i <= #parts do
      if parts[i] == "transform" and parts[i + 1] then
        spec.transform = tonumber(parts[i + 1]) or parts[i + 1]
        i = i + 2
      else
        i = i + 1
      end
    end

    print("hl.monitor(" .. lua_value(spec) .. ")")
  end
end

local function parse_workspace_rule(rule)
  local parts = split(rule, ",")
  local parsed = { workspace = parts[1] }

  for i = 2, #parts do
    local key, value = string.match(parts[i], "^([^:]+):(.+)$")
    if key and value then
      if value == "true" then
        parsed[key] = true
      elseif value == "false" then
        parsed[key] = false
      else
        parsed[key] = value
      end
    end
  end

  return parsed
end

local function emit_workspace_rules()
  for _, rule in ipairs(settings.workspace or {}) do
    print("hl.workspace_rule(" .. lua_value(parse_workspace_rule(rule)) .. ")")
  end
end

local function bind_key(mods, key)
  local tokens = {}
  mods = (mods or ""):gsub("_", " ")
  for token in string.gmatch(mods, "%S+") do
    table.insert(tokens, token)
  end
  if key and key ~= "" then
    table.insert(tokens, key)
  end
  return table.concat(tokens, " + ")
end

local function dispatcher_expr(dispatcher, arg)
  if dispatcher == "exec" then
    return "hl.dsp.exec_cmd(" .. lua_value(arg) .. ")"
  elseif dispatcher == "killactive" then
    return "hl.dsp.window.close()"
  elseif dispatcher == "workspace" then
    return "hl.dsp.focus({ workspace = " .. lua_value(arg) .. " })"
  elseif dispatcher == "movetoworkspace" then
    return "hl.dsp.window.move({ workspace = " .. lua_value(arg) .. " })"
  elseif dispatcher == "movewindow" then
    return "hl.dsp.window.drag()"
  elseif dispatcher == "resizewindow" then
    return "hl.dsp.window.resize()"
  end

  local raw = dispatcher .. (arg and arg ~= "" and " " .. arg or "")
  return "hl.dsp.exec_cmd(" .. lua_value("hyprctl dispatch " .. raw) .. ")"
end

local function emit_binds(name, opts)
  for _, bind in ipairs(settings[name] or {}) do
    local parts = split_limit(bind, ",", 4)
    local key = bind_key(parts[1], parts[2])
    local action = dispatcher_expr(parts[3], parts[4])
    print("hl.bind(" .. lua_value(key) .. ", " .. action .. ", " .. lua_value(opts or {}) .. ")")
  end
end

local boolean_match_keys = {
  float = true,
  fullscreen = true,
  pin = true,
  xwayland = true,
}

local boolean_action_keys = {
  center = true,
  float = true,
  fullscreen = true,
  keep_aspect_ratio = true,
  no_anim = true,
  no_focus = true,
  no_initial_focus = true,
  opaque = true,
  pin = true,
}

local function parse_rule_value(key, value, boolean_keys)
  if boolean_keys[key] then
    return boolish(value)
  elseif tonumber(value) then
    return tonumber(value)
  else
    return value
  end
end

local function parse_window_rule(rule, index)
  local parsed = { name = "nix-rule-" .. tostring(index), match = {} }
  for _, token in ipairs(split(rule, ",")) do
    local match_key, match_value = string.match(token, "^match:([^%s]+)%s+(.+)$")
    if match_key and match_value then
      parsed.match[match_key] = parse_rule_value(match_key, match_value, boolean_match_keys)
    else
      local key, value = string.match(token, "^([^%s]+)%s+(.+)$")
      if key and value then
        if key == "no_initial_focus" then
          parsed.no_focus = parse_rule_value("no_focus", value, boolean_action_keys)
        elseif key == "workspace" then
          parsed.workspace = value
        else
          parsed[key] = parse_rule_value(key, value, boolean_action_keys)
        end
      end
    end
  end
  return parsed
end

local function emit_window_rules()
  for index, rule in ipairs(settings.windowrule or {}) do
    print("hl.window_rule(" .. lua_value(parse_window_rule(rule, index)) .. ")")
  end
end

local function emit_autostart()
  if not settings["exec-once"] or #settings["exec-once"] == 0 then
    return
  end

  print("hl.on(\"hyprland.start\", function()")
  for _, command in ipairs(settings["exec-once"]) do
    print("  hl.exec_cmd(" .. lua_value(command) .. ")")
  end
  print("end)")
end

print("-- Generated from common/hyprland/default.nix.")
emit_config()
emit_monitors()
emit_workspace_rules()
emit_window_rules()
emit_binds("bind", {})
emit_binds("bindm", { mouse = true })
emit_binds("bindel", { locked = true, repeating = true })
emit_binds("bindl", { locked = true })
emit_autostart()
