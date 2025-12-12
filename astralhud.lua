-- AstralHUD - Summoner-focused informational HUD for Windower 4
-- Provides Blood Pact timers, avatar status, and simple buff tracking.

_addon.name     = 'astralhud'
_addon.author   = 'YourNameHere'
_addon.version  = '0.3.0'
_addon.commands = {'astralhud', 'ahud'}

local config = require('config')
local texts  = require('texts')
local res    = require('resources')

-- Recast group IDs for Summoner Blood Pacts.
local BP_RAGE_RECAST_ID = 173
local BP_WARD_RECAST_ID = 174

-- Buffs we track from Blood Pact: Ward.
local tracked_buffs = {
    ['Hastega II']       = {duration = 180},
    ['Hastega']          = {duration = 180},
    ['Earthen Armor']    = {duration = 90},
    ['Crimson Howl']     = {duration = 180},
    ['Ecliptic Howl']    = {duration = 90},
    ['Ecliptic Growl']   = {duration = 180},
    ['Dream Shroud']     = {duration = 180},
    ['Noctoshield']      = {duration = 180},
    ['Frost Armor']      = {duration = 180},
    ['Rolling Thunder']  = {duration = 180},
    ['Lightning Armor']  = {duration = 180},
    ['Soothing Current'] = {duration = 90},
    ['Spring Water']     = {duration = 90},
    ['Aerial Armor']     = {duration = 180},
}

local AVATAR_FAVOR_BUFF_ID = 650

local avatar_elements = {
    Ifrit = 'Fire',
    Shiva = 'Ice',
    Garuda = 'Wind',
    Titan = 'Earth',
    Ramuh = 'Lightning',
    Leviathan = 'Water',
    Carbuncle = 'Light',
    Fenrir = 'Dark',
    Diabolos = 'Dark',
    ['Cait Sith'] = 'Light',
}

local avatar_perp = {
    Ifrit = 7, Shiva = 7, Garuda = 7, Titan = 7, Ramuh = 7, Leviathan = 7,
    Carbuncle = 5, Fenrir = 7, Diabolos = 7, ['Cait Sith'] = 7,
}

local element_colors = {
    Fire = {255, 100, 60},
    Ice = {140, 200, 255},
    Wind = {120, 230, 120},
    Earth = {200, 160, 90},
    Lightning = {200, 120, 255},
    Water = {120, 180, 255},
    Light = {250, 250, 180},
    Dark = {180, 130, 200},
}

-- Day/Weather element mappings (Vana'diel day/weather IDs to element names)
local day_elements = {
    [0] = 'Fire',      -- Firesday
    [1] = 'Earth',     -- Earthsday
    [2] = 'Water',     -- Watersday
    [3] = 'Wind',      -- Windsday
    [4] = 'Ice',       -- Iceday
    [5] = 'Lightning', -- Lightningday
    [6] = 'Light',     -- Lightsday
    [7] = 'Dark',      -- Darksday
}

local weather_elements = {
    [0] = 'None',
    [1] = 'Fire',      -- Sunny/Hot
    [2] = 'Fire',      -- Heat Wave
    [3] = 'Water',     -- Rain
    [4] = 'Water',     -- Squall
    [5] = 'Earth',     -- Dust Storm
    [6] = 'Earth',     -- Sand Storm
    [7] = 'Wind',      -- Wind
    [8] = 'Wind',      -- Gales
    [9] = 'Ice',       -- Snow
    [10] = 'Ice',      -- Blizzards
    [11] = 'Lightning',-- Thunder
    [12] = 'Lightning',-- Thunderstorms
    [13] = 'Light',    -- Auroras
    [14] = 'Light',    -- Stellar Glare
    [15] = 'Dark',     -- Gloom
    [16] = 'Dark',     -- Darkness
}

-- Default settings
local defaults = {
    visible = true,
    show_non_smn = false,
    debug = false,
    size_profile = 'normal',
    size_profiles = {
        xsmall = {font_size = 8, stroke = 1, padding = 1},
        small  = {font_size = 9, stroke = 2, padding = 2},
        normal = {font_size = 11, stroke = 2, padding = 4},
        large  = {font_size = 14, stroke = 3, padding = 6},
        xlarge = {font_size = 17, stroke = 3, padding = 7},
    },
    modules = {
        bptimers     = true,
        pet          = true,
        buffs        = true,
        jobabilities = true,
    },
    panel_text = {
        pos   = {x = 60, y = 60},
        text  = {font = 'Consolas', size = 11, red = 235, green = 240, blue = 255, stroke = {width = 2, alpha = 255, red = 0, green = 0, blue = 0}},
        bg    = {alpha = 200, red = 10, green = 15, blue = 25},
        flags = {draggable = true, bold = true},
        padding = 4,
    },
}

local state = {
    settings = config.load(defaults),
    buffs = {},
    tracked_ids = {},
    last_update = 0,
    bp_max = {rage = 45, ward = 45},
    favor_start = nil,
    astral_flow_start = nil,
    astral_conduit_start = nil,
    pet_hp_track = {hpp = nil, t = nil, dps_pct = 0},
    mp_track = {mp = nil, t = nil, per_sec = 0},
    pet_dead_at = nil,
    job_ability_max = {},
}

local ui = {
    panel_text = nil,
}

local smn_job_ability_names = {
    -- SMN job abilities with meaningful recasts to surface in the HUD.
    ['Elemental Siphon'] = true,
    ['Mana Cede'] = true,
    ['Apogee'] = true,
    ['Astral Flow'] = true,
    ['Astral Conduit'] = true,
}

local smn_job_abilities = {}

local function build_smn_job_abilities()
    smn_job_abilities = {}
    for id, ability in pairs(res.job_abilities) do
        if ability and smn_job_ability_names[ability.en] and ability.recast_id then
            smn_job_abilities[id] = ability
        end
    end
end

local function build_tracked_ids()
    local mapping = {}
    for id, ability in pairs(res.job_abilities) do
        local name = ability.en
        if tracked_buffs[name] then
            mapping[id] = name
        end
    end
    state.tracked_ids = mapping
end

local function table_to_id_set(list)
    local ids = {}
    if not list then return ids end
    if #list > 0 then
        for _, id in ipairs(list) do
            ids[id] = true
        end
    else
        for id, has in pairs(list) do
            if has then ids[id] = true end
        end
    end
    return ids
end

local function clamp(v, minv, maxv)
    if v < minv then return minv end
    if v > maxv then return maxv end
    return v
end

local function make_bar(pct, length)
    pct = clamp(pct or 0, 0, 1)
    local filled = math.floor(pct * length + 0.5)
    local empty = length - filled
    return ('[%s%s]'):format(string.rep('=', filled), string.rep('-', empty))
end

local function resolve_buff_id(name)
    for id, buff in pairs(res.buffs) do
        if buff.en == name then
            return id
        end
    end
    return nil
end

local function fmt_time(seconds)
    if not seconds or seconds < 0 then
        return '0:00'
    end
    local m = math.floor(seconds / 60)
    local s = math.floor(seconds % 60)
    return ('%d:%02d'):format(m, s)
end

local function is_smn()
    local player = windower.ffxi.get_player()
    return player and (player.main_job_id == 15 or player.sub_job_id == 15)
end

local function init_ui()
    if not state.settings.panel_text then
        state.settings.panel_text = defaults.panel_text
    end
    if not state.settings.panel_text.bg then
        state.settings.panel_text.bg = defaults.panel_text.bg
    elseif not state.settings.panel_text.bg.alpha then
        state.settings.panel_text.bg.alpha = defaults.panel_text.bg.alpha
    end
    if not state.settings.modules then
        state.settings.modules = defaults.modules
    end
    if state.settings.modules.jobabilities == nil then
        state.settings.modules.jobabilities = defaults.modules.jobabilities
    end
    if not state.settings.size_profiles then
        state.settings.size_profiles = defaults.size_profiles
    end
    if not state.settings.size_profile then
        state.settings.size_profile = defaults.size_profile
    end
    ui.panel_text = texts.new(state.settings.panel_text)
    local profile = state.settings.size_profiles[state.settings.size_profile]
    if profile and ui.panel_text then
        if ui.panel_text.size then pcall(function() ui.panel_text:size(profile.font_size) end) end
        if ui.panel_text.padding then pcall(function() ui.panel_text:padding(profile.padding) end) end
        if ui.panel_text.stroke_width then pcall(function() ui.panel_text:stroke_width(profile.stroke) end) end
    end
end

local function destroy_ui()
    if ui.panel_text then ui.panel_text:destroy() end
    ui.panel_text = nil
end

local function print_help()
    windower.add_to_chat(207, '[AstralHUD] Commands:')
    windower.add_to_chat(207, '  //astralhud | //ahud              - show this help')
    windower.add_to_chat(207, '  //astralhud toggle                - toggle HUD visibility')
    windower.add_to_chat(207, '  //astralhud enable <module>       - enable module (bptimers, pet, buffs, jobabilities)')
    windower.add_to_chat(207, '  //astralhud disable <module>      - disable module (bptimers, pet, buffs, jobabilities)')
    windower.add_to_chat(207, '  //astralhud reset                 - reset positions/settings to default')
    windower.add_to_chat(207, '  //astralhud showall on|off        - show HUD even when not on SMN')
    windower.add_to_chat(207, '  //astralhud debug on|off          - toggle buff tracking debug messages')
    windower.add_to_chat(207, '  //astralhud size xsmall|small|normal|large|xlarge - change HUD size')
    windower.add_to_chat(207, '  //astralhud bgopacity 0-255       - set HUD background opacity')
    windower.add_to_chat(207, '  //astralhud listbuffs             - list all tracked ward buff IDs')
end

local function toggle_visibility()
    state.settings.visible = not state.settings.visible
    config.save(state.settings)
    local status = state.settings.visible and 'shown' or 'hidden'
    windower.add_to_chat(207, ('[AstralHUD] HUD %s.'):format(status))

    if ui.panel_text then ui.panel_text:visible(state.settings.visible) end
end

local function set_background_opacity(alpha)
    local value = tonumber(alpha)
    if not value then
        return nil, 'Opacity must be a number between 0 and 255.'
    end

    value = clamp(math.floor(value + 0.5), 0, 255)
    state.settings.panel_text.bg = state.settings.panel_text.bg or {}
    state.settings.panel_text.bg.alpha = value
    config.save(state.settings)

    if ui.panel_text and ui.panel_text.bg_alpha then
        pcall(function() ui.panel_text:bg_alpha(value) end)
    end

    return value
end

local function handle_command(cmd, ...)
    cmd = cmd and cmd:lower() or ''
    local args = {...}

    if cmd == 'toggle' then
        toggle_visibility()
        return
    elseif cmd == 'enable' then
        local module = args[1] and args[1]:lower()
        if module and state.settings.modules[module] ~= nil then
            state.settings.modules[module] = true
            config.save(state.settings)
            windower.add_to_chat(207, ('[AstralHUD] Module "%s" enabled.'):format(module))
        else
            windower.add_to_chat(207, '[AstralHUD] Unknown module. Use: bptimers, pet, buffs, jobabilities')
        end
        return
    elseif cmd == 'disable' then
        local module = args[1] and args[1]:lower()
        if module and state.settings.modules[module] ~= nil then
            state.settings.modules[module] = false
            config.save(state.settings)
            windower.add_to_chat(207, ('[AstralHUD] Module "%s" disabled.'):format(module))
        else
            windower.add_to_chat(207, '[AstralHUD] Unknown module. Use: bptimers, pet, buffs, jobabilities')
        end
        return
    elseif cmd == 'reset' then
        state.settings = config.load(defaults)
        config.save(state.settings)
        destroy_ui()
        init_ui()
        windower.add_to_chat(207, '[AstralHUD] Settings reset to defaults.')
        return
    elseif cmd == 'showall' then
        local arg = args[1] and args[1]:lower()
        if arg == 'on' then
            state.settings.show_non_smn = true
            config.save(state.settings)
            windower.add_to_chat(207, '[AstralHUD] HUD will now show even when not on SMN.')
        elseif arg == 'off' then
            state.settings.show_non_smn = false
            config.save(state.settings)
            windower.add_to_chat(207, '[AstralHUD] HUD will only show on SMN.')
        else
            windower.add_to_chat(207, '[AstralHUD] Usage: //astralhud showall on|off')
        end
        return
    elseif cmd == 'debug' then
        local arg = args[1] and args[1]:lower()
        if arg == 'on' then
            state.settings.debug = true
            config.save(state.settings)
            windower.add_to_chat(207, '[AstralHUD] Debug mode enabled.')
        elseif arg == 'off' then
            state.settings.debug = false
            config.save(state.settings)
            windower.add_to_chat(207, '[AstralHUD] Debug mode disabled.')
        else
            windower.add_to_chat(207, '[AstralHUD] Usage: //astralhud debug on|off')
        end
        return
    elseif cmd == 'size' then
        local which = args[1] and args[1]:lower()
        if not which or not state.settings.size_profiles[which] then
            windower.add_to_chat(207, '[AstralHUD] Usage: //astralhud size xsmall|small|normal|large|xlarge')
            return
        end
        state.settings.size_profile = which
        config.save(state.settings)
        local profile = state.settings.size_profiles[which]
        -- Update live UI if present
        if ui.panel_text then
            if ui.panel_text.size then pcall(function() ui.panel_text:size(profile.font_size) end) end
            if ui.panel_text.padding then pcall(function() ui.panel_text:padding(profile.padding) end) end
            if ui.panel_text.stroke_width then pcall(function() ui.panel_text:stroke_width(profile.stroke) end) end
        end
        windower.add_to_chat(207, ('[AstralHUD] Size set to %s.'):format(which))
        return
    elseif cmd == 'listbuffs' then
        windower.add_to_chat(207, '[AstralHUD] Tracked Ward Buff IDs:')
        local sorted_buffs = {}
        for id, name in pairs(state.tracked_ids) do
            table.insert(sorted_buffs, {id = id, name = name})
        end
        table.sort(sorted_buffs, function(a, b) return a.name < b.name end)
        for _, buff in ipairs(sorted_buffs) do
            windower.add_to_chat(207, ('  [%d] %s'):format(buff.id, buff.name))
        end
        if #sorted_buffs == 0 then
            windower.add_to_chat(207, '  No buffs tracked (resources not loaded yet?)')
        end
        return
    elseif cmd == 'bgopacity' or cmd == 'bgalpha' then
        local alpha = args[1]
        local applied, err = set_background_opacity(alpha)
        if applied then
            windower.add_to_chat(207, ('[AstralHUD] Background opacity set to %d.'):format(applied))
        else
            windower.add_to_chat(207, '[AstralHUD] Usage: //astralhud bgopacity 0-255')
            if err then
                windower.add_to_chat(207, '[AstralHUD] ' .. err)
            end
        end
        return
    end

    print_help()
end

local function update_bp_timers()
    if not state.settings.modules.bptimers then return {lines = {}, rage_cd = 0, ward_cd = 0} end

    local recasts = windower.ffxi.get_ability_recasts()
    if not recasts then return {lines = {'Recast data unavailable'}, rage_cd = 0, ward_cd = 0} end

    local rage = recasts[BP_RAGE_RECAST_ID] or 0
    local ward = recasts[BP_WARD_RECAST_ID] or 0

    if rage > state.bp_max.rage then state.bp_max.rage = rage end
    if ward > state.bp_max.ward then state.bp_max.ward = ward end

    local rage_status = rage > 0 and fmt_time(rage) or 'READY'
    local ward_status = ward > 0 and fmt_time(ward) or 'READY'

    local rage_pct = state.bp_max.rage > 0 and (1 - rage / state.bp_max.rage) or 1
    local ward_pct = state.bp_max.ward > 0 and (1 - ward / state.bp_max.ward) or 1

    local bar_len = 12
    local rage_bar = make_bar(rage_pct, bar_len)
    local ward_bar = make_bar(ward_pct, bar_len)

    return {
        lines = {
            string.format('Rage: %s %s  |  Ward: %s %s', rage_status, rage_bar, ward_status, ward_bar),
        },
        rage_cd = rage,
        ward_cd = ward,
    }
end

local function update_smn_job_abilities()
    if not state.settings.modules.jobabilities then return {} end

    if not next(smn_job_abilities) then
        build_smn_job_abilities()
    end

    local abilities = windower.ffxi.get_abilities()
    if not abilities or not abilities.job_abilities then
        return {'Job ability data unavailable'}
    end

    local unlocked = table_to_id_set(abilities.job_abilities)
    local recasts = windower.ffxi.get_ability_recasts() or {}
    local entries = {}

    for id, ability in pairs(smn_job_abilities) do
        if unlocked[id] then
            local recast_id = ability.recast_id
            if recast_id then
                local cd = recasts[recast_id] or 0
                state.job_ability_max[recast_id] = math.max(state.job_ability_max[recast_id] or cd, cd)
                table.insert(entries, {
                    name = ability.en,
                    recast = cd,
                    recast_id = recast_id,
                    max = state.job_ability_max[recast_id] or cd,
                })
            end
        end
    end

    if #entries == 0 then
        return {'No Summoner job abilities unlocked'}
    end

    table.sort(entries, function(a, b) return a.name < b.name end)
    local lines = {}
    for _, entry in ipairs(entries) do
        local status = entry.recast > 0 and fmt_time(entry.recast) or 'READY'
        local bar = ''
        if entry.max and entry.max > 0 then
            local pct = 1 - (entry.recast / entry.max)
            bar = ' ' .. make_bar(pct, 12)
        end
        table.insert(lines, string.format('%s: %s%s', entry.name, status, bar))
    end

    return lines
end

local function update_pet_info()
    if not state.settings.modules.pet then return {} end

    local pet = windower.ffxi.get_mob_by_target('pet')
    local player = windower.ffxi.get_player()

    if not pet or not player then
        if not state.pet_dead_at then
            state.pet_dead_at = os.time()
        end
        state.pet_hp_track = {hpp = nil, t = nil, dps_pct = 0}
        return {'Avatar: None summoned', 'Resummon when ready'}
    end

    state.pet_dead_at = nil

    local hp = pet.hp or 0
    local hpp = pet.hpp or 0
    local mp = pet.mp or 0
    local mpp = pet.mpp or 0
    local tp = pet.tp or 0

    local element = avatar_elements[pet.name] or 'Unknown'
    local perp = avatar_perp[pet.name] or 0

    local buffs = player.buffs or {}
    local has_favor = false
    for _, buff_id in ipairs(buffs) do
        if buff_id == AVATAR_FAVOR_BUFF_ID then
            has_favor = true
            break
        end
    end

    local favor_status = has_favor and 'ON' or 'OFF'
    if has_favor and state.favor_start then
        favor_status = ('ON (%s)'):format(fmt_time(os.time() - state.favor_start))
    end

    local summoning_skill = 0
    if player.skills and player.skills.summoning then
        summoning_skill = player.skills.summoning
    end

    local day_info = windower.ffxi.get_info()
    local day_element = 'Unknown'
    local weather_element = 'None'

    if day_info then
        if day_info.day and day_elements[day_info.day] then
            day_element = day_elements[day_info.day]
        end
        if day_info.weather and weather_elements[day_info.weather] then
            weather_element = weather_elements[day_info.weather]
        end
    end

    local bar_len = 12
    local hp_bar = make_bar(hpp / 100, bar_len)
    local mp_bar = make_bar(mpp / 100, bar_len)

    -- Convert pet status to readable text
    local status_text = 'Unknown'
    if type(pet.status) == 'number' then
        local status_names = {[0] = 'Idle', [1] = 'Engaged', [2] = 'Dead', [3] = 'Idle', [4] = 'Idle'}
        status_text = status_names[pet.status] or 'Unknown'
    elseif type(pet.status) == 'string' then
        status_text = pet.status:sub(1,1):upper() .. pet.status:sub(2):lower()
    end

    -- Track incoming damage as %/sec with a light smoothing
    local now = os.time()
    if state.pet_hp_track.hpp and state.pet_hp_track.t and now > state.pet_hp_track.t then
        local delta = state.pet_hp_track.hpp - hpp
        local elapsed = now - state.pet_hp_track.t
        local dps_pct = delta / math.max(elapsed, 1)
        state.pet_hp_track.dps_pct = (state.pet_hp_track.dps_pct * 0.7) + (dps_pct * 0.3)
    end
    state.pet_hp_track.hpp = hpp
    state.pet_hp_track.t = now

    local incoming_5s = state.pet_hp_track.dps_pct * 5
    local ttk = ''
    if state.pet_hp_track.dps_pct > 0.01 then
        local seconds = hpp / state.pet_hp_track.dps_pct
        ttk = string.format('TTK ~%s', fmt_time(seconds))
    end

    -- Favor range: count party members within 10y of the avatar
    local in_range = 0
    local party = windower.ffxi.get_party() or {}
    local function to_mob(m)
        if type(m) == 'table' then return m end
        if type(m) == 'number' then return windower.ffxi.get_mob_by_id(m) end
        return nil
    end
    local function dist(a, b)
        a = to_mob(a)
        b = to_mob(b)
        if not a or not b then return math.huge end
        local dx = (a.x or 0) - (b.x or 0)
        local dy = (a.y or 0) - (b.y or 0)
        return math.sqrt(dx * dx + dy * dy)
    end
    for _, member in pairs(party) do
        if type(member) == 'table' and member.mob then
            if dist(member.mob, pet) <= 10 then
                in_range = in_range + 1
            end
        end
    end

    -- Alignment callouts
    local alignment = {}
    if element == day_element then table.insert(alignment, 'Day aligned') end
    if element == weather_element then table.insert(alignment, 'Weather aligned') end
    local align_text = #alignment > 0 and table.concat(alignment, ' & ') or 'No env alignment'

    local low_hp_alert = hpp <= 30 and 'LOW HP' or ''

    local vitals_line = string.format('HP %3d%% %s  MP %3d%% (%d) %s  TP: %d', hpp, hp_bar, mpp, mp, mp_bar, tp)

    return {
        string.format('%s (%s)', pet.name, status_text),
        vitals_line,
        string.format('Element: %s  Day: %s  Weather: %s', element, day_element, weather_element),
        string.format('Summoning: %d  Favor: %s  Perp: %d MP/tick', summoning_skill, favor_status, perp),
        string.format('Favor range: %d party in 10y  |  %s', in_range, align_text),
        string.format('Dmg/5s: %d%%  %s %s', math.floor(incoming_5s + 0.5), ttk, low_hp_alert),
    }
end

local function update_buff_display()
    if not state.settings.modules.buffs then return {} end

    local now = os.time()
    for buff, info in pairs(state.buffs) do
        if now >= info.expires then
            state.buffs[buff] = nil
        end
    end

    if next(state.buffs) == nil then
        return {'No ward buffs tracked yet'}
    end

    local lines = {}
    local ordered = {}
    for buff, info in pairs(state.buffs) do
        table.insert(ordered, {name = buff, info = info})
    end
    table.sort(ordered, function(a, b)
        return a.info.expires < b.info.expires
    end)

    for _, entry in ipairs(ordered) do
        local remaining = entry.info.expires - now
        if remaining > 0 then
            local target_str = table.concat(entry.info.targets, ', ')
            table.insert(lines, string.format('%s [%s] -> %s', entry.name, fmt_time(remaining), target_str))
        end
    end

    return lines
end

local function pact_guidance()
    local pet = windower.ffxi.get_mob_by_target('pet')
    if not pet then return {} end

    local info = windower.ffxi.get_info()
    local day_element = (info and info.day and day_elements[info.day]) or 'Unknown'
    local weather_element = (info and info.weather and weather_elements[info.weather]) or 'None'
    local element = avatar_elements[pet.name] or 'Unknown'

    local highlights = {}
    if element == day_element then table.insert(highlights, 'Day aligned') end
    if element == weather_element then table.insert(highlights, 'Weather aligned') end

    local best = weather_element ~= 'None' and weather_element or day_element
    local guidance = {}
    table.insert(guidance, string.format('Current: %s element (%s)', element, pet.name))
    table.insert(guidance, string.format('Day: %s  Weather: %s', day_element, weather_element))

    if #highlights > 0 then
        table.insert(guidance, 'Aligned: ' .. table.concat(highlights, ' & '))
    elseif best and best ~= 'Unknown' and best ~= 'None' then
        table.insert(guidance, string.format('Consider swapping to %s alignment.', best))
    else
        table.insert(guidance, 'No elemental alignment bonus detected.')
    end

    return guidance
end

local function update_astral_banners()
    local player = windower.ffxi.get_player()
    if not player or not player.buffs then return {} end

    local now = os.time()
    local astral_flow_id = resolve_buff_id('Astral Flow')
    local astral_conduit_id = resolve_buff_id('Astral Conduit')

    local active = {}

    local has_flow, has_conduit = false, false
    for _, buff_id in ipairs(player.buffs) do
        if buff_id == astral_flow_id then has_flow = true end
        if buff_id == astral_conduit_id then has_conduit = true end
    end

    if has_flow then
        if not state.astral_flow_start then state.astral_flow_start = now end
        local elapsed = now - state.astral_flow_start
        local remaining = math.max(0, 30 - elapsed)
        table.insert(active, string.format('Astral Flow ACTIVE [%s left]', fmt_time(remaining)))
    else
        state.astral_flow_start = nil
    end

    if has_conduit then
        if not state.astral_conduit_start then state.astral_conduit_start = now end
        local elapsed = now - state.astral_conduit_start
        local remaining = math.max(0, 30 - elapsed)
        table.insert(active, string.format('Astral Conduit ACTIVE [%s left]', fmt_time(remaining)))
    else
        state.astral_conduit_start = nil
    end

    if #active == 0 then return {} end

    local pet = windower.ffxi.get_mob_by_target('pet')
    local element = pet and avatar_elements[pet.name] or 'Elemental'
    local burst_hint = {
        Fire = 'Inferno/Flaming Crush chain',
        Ice = 'Diamond Dust/Heavenly Strike chain',
        Wind = 'Aerial Blast/Wind Blade chain',
        Earth = 'Earthen Fury/Geocrush chain',
        Lightning = 'Judgment Bolt/Thunderstorm chain',
        Water = 'Tidal Wave/Grand Fall chain',
        Light = 'Holy Mist/Fountain of Arrogance',
        Dark = 'Night Terror/Ruinous Omen',
    }

    local hint = burst_hint[element] or 'Burst now!'
    table.insert(active, 'Recommended: ' .. hint)

    return active
end

local function update_mp_economy()
    local player = windower.ffxi.get_player()
    if not player then return {} end

    local now = os.time()
    local mp = player.vitals and player.vitals.mp or player.mp
    if mp then
        if state.mp_track.mp and state.mp_track.t and now > state.mp_track.t then
            local delta = mp - state.mp_track.mp
            local elapsed = now - state.mp_track.t
            local per_sec = delta / math.max(elapsed, 1)
            state.mp_track.per_sec = (state.mp_track.per_sec * 0.7) + (per_sec * 0.3)
        end
        state.mp_track.mp = mp
        state.mp_track.t = now
    end

    local per_tick = state.mp_track.per_sec * 3
    local t_oom = ''
    if state.mp_track.per_sec < -0.1 and mp then
        local seconds = mp / -state.mp_track.per_sec
        t_oom = string.format(' TtOOM ~%s', fmt_time(seconds))
    end

    local pet = windower.ffxi.get_mob_by_target('pet')
    local perp_val = pet and avatar_perp[pet.name] or 0

    return {
        string.format('MP/tick: %+0.1f  (net %+.1f/s)%s', per_tick, state.mp_track.per_sec, t_oom),
        string.format('Perp drain est: %d/tick (avatar)', perp_val),
    }
end

local function update_hud()
    local now = os.time()
    if now - state.last_update < 0.5 then return end
    state.last_update = now

    if not state.settings.show_non_smn and not is_smn() then
        if ui.panel_text then ui.panel_text:visible(false) end
        return
    end

    if not ui.panel_text then return end

    ui.panel_text:visible(state.settings.visible)
    if not state.settings.visible then return end

    local function append_section(lines, title, content)
        if #content == 0 then return end
        table.insert(lines, title)
        for _, line in ipairs(content) do
            table.insert(lines, '  ' .. line)
        end
        table.insert(lines, '')
    end

    local lines = {}
    local bp = update_bp_timers()
    append_section(lines, '[Astral Burst]', update_astral_banners())
    append_section(lines, '[Blood Pacts]', bp.lines)
    append_section(lines, '[SMN Job Abilities]', update_smn_job_abilities())
    append_section(lines, '[Avatar]', update_pet_info())
    append_section(lines, '[Guidance]', pact_guidance())
    append_section(lines, '[Ward Buffs]', update_buff_display())
    append_section(lines, '[MP Economy]', update_mp_economy())

    -- Trim trailing empty spacer for cleaner text block
    while #lines > 0 and lines[#lines] == '' do
        table.remove(lines)
    end

    if #lines == 0 then
        table.insert(lines, 'AstralHUD is ready - enable modules to show data.')
    end

    ui.panel_text:text(table.concat(lines, '\n'))
end

windower.register_event('load', function()
    build_tracked_ids()
    build_smn_job_abilities()
    init_ui()

    if state.settings.visible then
        update_hud()
    end
end)

windower.register_event('unload', function()
    destroy_ui()
    config.save(state.settings)
end)

windower.register_event('login', function()
    destroy_ui()
    build_smn_job_abilities()
    init_ui()
end)

windower.register_event('logout', function()
    destroy_ui()
end)

windower.register_event('addon command', handle_command)

windower.register_event('prerender', function()
    update_hud()
end)

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
    if id == 0x028 then  -- Action packet
        local act = windower.packets.parse_action(data)
        if not act then return end

        local player = windower.ffxi.get_player()
        if not player then return end

        -- Ward buffs are cast by the pet (avatar) as Blood Pact: Ward
        -- Check if action is from player's pet
        local pet = windower.ffxi.get_mob_by_target('pet')
        local is_pet_action = pet and act.actor_id == pet.id
        local is_player_action = act.actor_id == player.id

        -- Category 13 = pet ability (Blood Pacts), Category 6 = job ability
        if (is_pet_action and act.category == 13) or (is_player_action and act.category == 6) then
            if state.settings.debug then
                local actor_type = is_pet_action and 'Pet' or 'Player'
                windower.add_to_chat(207, ('[AstralHUD] %s Action - Category: %d, Actor ID: %d'):format(actor_type, act.category, act.actor_id))
            end

            for _, target in ipairs(act.targets) do
                for _, action in ipairs(target.actions) do
                    local ability_id = action.param

                    if state.settings.debug then
                        windower.add_to_chat(207, ('[AstralHUD] Ability ID: %d'):format(ability_id))
                    end

                    local buff_name = state.tracked_ids[ability_id]
                    if buff_name then
                        local buff_info = tracked_buffs[buff_name]
                        if buff_info then
                            local target_mob = windower.ffxi.get_mob_by_id(target.id)
                            local target_name = target_mob and target_mob.name or 'Unknown'

                            if not state.buffs[buff_name] then
                                state.buffs[buff_name] = {
                                    expires = os.time() + buff_info.duration,
                                    targets = {}
                                }
                            else
                                state.buffs[buff_name].expires = os.time() + buff_info.duration
                            end

                            local found = false
                            for _, name in ipairs(state.buffs[buff_name].targets) do
                                if name == target_name then
                                    found = true
                                    break
                                end
                            end
                            if not found then
                                table.insert(state.buffs[buff_name].targets, target_name)
                            end

                            windower.add_to_chat(207, ('[AstralHUD] Tracked: %s on %s (%ds)'):format(buff_name, target_name, buff_info.duration))
                        end
                    end
                end
            end
        end
    elseif id == 0x063 then  -- Buff update
        local player = windower.ffxi.get_player()
        if not player then return end

        local buffs = player.buffs or {}
        local has_favor = false
        local has_flow = false
        local has_conduit = false
        local astral_flow_id = resolve_buff_id('Astral Flow')
        local astral_conduit_id = resolve_buff_id('Astral Conduit')

        for _, buff_id in ipairs(buffs) do
            if buff_id == AVATAR_FAVOR_BUFF_ID then
                has_favor = true
            end
            if buff_id == astral_flow_id then
                has_flow = true
            end
            if buff_id == astral_conduit_id then
                has_conduit = true
            end
        end

        if has_favor and not state.favor_start then
            state.favor_start = os.time()
        elseif not has_favor and state.favor_start then
            state.favor_start = nil
        end

        if has_flow and not state.astral_flow_start then
            state.astral_flow_start = os.time()
        elseif not has_flow then
            state.astral_flow_start = nil
        end

        if has_conduit and not state.astral_conduit_start then
            state.astral_conduit_start = os.time()
        elseif not has_conduit then
            state.astral_conduit_start = nil
        end
    end
end)
