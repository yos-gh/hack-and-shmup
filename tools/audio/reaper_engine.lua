-- Shared REAPER synthesis/render engine; no project changes until a method is called.
return function(out, log)
local function report(s) log:write(s .. "\n"); log:flush() end
local function db(value) return 10 ^ (value / 20) end

-- Read back formatted values so nonlinear plug-in scales are not guessed.
local function physical(track, fx, param, target)
  local lower, upper = 0, 1
  for _ = 1, 24 do
    local mid = (lower + upper) / 2
    reaper.TrackFX_SetParamNormalized(track, fx, param, mid)
    local _, formatted = reaper.TrackFX_GetFormattedParamValue(track, fx, param, '')
    local value = tonumber(formatted:match('[+-]?%d+%.?%d*'))
    if not value then
      assert(formatted:find('inf'), 'Non-numeric parameter ' .. param .. ': ' .. formatted)
      value = -math.huge
    end
    if value < target then lower = mid else upper = mid end
  end
  reaper.TrackFX_SetParamNormalized(track, fx, param, math.min(1, upper + 0.000001))
end

local voices = {
  kick = {osc=.5, decay=.13, bend=24, bendtime=.022},
  kick_edge = {osc=1, decay=.010},
  snare_body = {osc=.5, decay=.055, bend=14, bendtime=.014},
  snare_noise = {osc=1, decay=.095},
  hat = {osc=1, decay=.024, algorithm=1},
  open_hat = {osc=1, decay=.092, algorithm=.5},
  sub = {osc=.5, decay=.10, sustain=.55, release=.012},
  bass = {osc=0, duty=.5, decay=.075, sustain=.15, release=.009, bend=2, bendtime=.009},
  stab = {osc=0, duty=1, decay=.09, sustain=.1, release=.045},
  lead = {osc=0, duty=.5, decay=.065, sustain=.3, release=.026, bend=1, bendtime=.014},
  arp = {osc=0, duty=0, decay=.033, sustain=.05, release=.022},
  spark = {osc=1, algorithm=1, decay=.085, bend=10, bendtime=.06},
  shot_tone = {osc=0, duty=.5, decay=.043, bend=18, bendtime=.033},
  shot_edge = {osc=1, decay=.021},
  scatter_tone = {osc=0, duty=1, decay=.10, bend=17, bendtime=.075},
  scatter_noise = {osc=1, decay=.125},
  shock_body = {osc=.5, decay=.27, bend=24, bendtime=.12, release=.035},
  shock_noise = {osc=1, algorithm=1, decay=.19, bend=18, bendtime=.12},
  lance_tone = {osc=0, duty=0, decay=.14, bend=24, bendtime=.14},
  lance_low = {osc=0, duty=.5, decay=.095, bend=12, bendtime=.08},
  hit_tone = {osc=0, duty=1, decay=.030, bend=10, bendtime=.018},
  kill_tone = {osc=0, duty=.5, decay=.08, bend=21, bendtime=.075},
  kill_noise = {osc=1, algorithm=1, decay=.095, bend=12, bendtime=.08},
  lock_tone = {osc=0, duty=.5, decay=.026, bend=-5, bendtime=.025},
  death_tone = {osc=0, duty=1, decay=.24, bend=24, bendtime=.22},
  death_noise = {osc=1, algorithm=1, decay=.22, bend=20, bendtime=.16},
}

local function add_fx(track, name)
  local fx = reaper.TrackFX_AddByName(track, name, false, -1)
  assert(fx >= 0, 'Could not load ' .. name)
  return fx
end

local function make_track(name, voice_name, level, pan, echo, patch)
  local index = reaper.CountTracks(0)
  reaper.InsertTrackAtIndex(index, true)
  local track = reaper.GetTrack(0, index)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', name, true)
  reaper.SetMediaTrackInfo_Value(track, 'D_VOL', db(level))
  reaper.SetMediaTrackInfo_Value(track, 'D_PAN', pan or 0)
  local fx = add_fx(track, 'VST3i: Magical 8bit Plug 2 (Ymck)')
  local voice = {}
  for k,v in pairs(assert(voices[voice_name], voice_name)) do voice[k]=v end
  for k,v in pairs(patch or {}) do voice[k]=v end
  local expected = {[2]='OSC Type',[5]='Attack',[6]='Decay',[7]='Sustain',
                    [8]='Release',[18]='Ini.Pitch',[19]='Time',[20]='Duty'}
  for i, name in pairs(expected) do
    local _, found = reaper.TrackFX_GetParamName(track, fx, i, '')
    assert(found == name, 'Unsupported synth parameter map: ' .. found)
  end
  reaper.TrackFX_SetParamNormalized(track, fx, 2, voice.osc)
  reaper.TrackFX_SetParamNormalized(track, fx, 3, .8)
  physical(track, fx, 5, voice.attack or .001)
  physical(track, fx, 6, voice.decay)
  physical(track, fx, 7, voice.sustain or 0)
  physical(track, fx, 8, voice.release or .006)
  physical(track, fx, 18, voice.bend or 0)
  physical(track, fx, 19, voice.bendtime or .03)
  reaper.TrackFX_SetParamNormalized(track, fx, 20, voice.duty or 0)
  reaper.TrackFX_SetParamNormalized(track, fx, 21, voice.algorithm or .5)
  local _, oscillator = reaper.TrackFX_GetFormattedParamValue(track, fx, 2, '')
  report(name .. ' / ' .. voice_name .. ' / ' .. oscillator)
  if voice.saturation then
    local saturator = add_fx(track, 'JS: loser/saturation')
    reaper.TrackFX_SetParamNormalized(track, saturator, 0, voice.saturation)
  end
  -- Mild top-end restraint keeps pulse/noise layers from masking game warnings.
  local eq = add_fx(track, 'VST: ReaEQ (Cockos)')
  physical(track, eq, 9, voice.filter or 4800)
  physical(track, eq, 10, voice.top or (voice.osc == 1 and -7 or -3))
  if reaper.TrackFX_GetNumParams(track, eq) >= 19 then physical(track, eq, 12, 25) end
  if echo then
    local config = type(echo)=='table' and echo or {}
    local delay = add_fx(track, 'VST: ReaDelay (Cockos)')
    physical(track, delay, 0, config.wet or -16)
    physical(track, delay, 1, 0)
    physical(track, delay, 3, config.time or 140.625)
    reaper.TrackFX_SetParamNormalized(track, delay, 4, 0)
    physical(track, delay, 5, config.feedback or -12)
    physical(track, delay, 6, config.cutoff or 5200)
    physical(track, delay, 7, config.highpass or 500)
    physical(track, delay, 10, 0)
  end
  return track
end

local function add_notes(track, notes, seconds_per_beat, duration, repeats)
  local item = reaper.CreateNewMIDIItemInProj(track, 0, duration * repeats, false)
  local take = reaper.GetActiveTake(item)
  for repetition = 0, repeats - 1 do
    for _, n in ipairs(notes) do
      local t = repetition * duration + n[1] * seconds_per_beat
      reaper.MIDI_InsertNote(take, false, false,
        reaper.MIDI_GetPPQPosFromProjTime(take, t),
        reaper.MIDI_GetPPQPosFromProjTime(take, t+n[3]*seconds_per_beat),
        0, n[2], n[4], true)
    end
  end
  reaper.MIDI_Sort(take)
end

local function new_project(bpm)
  reaper.Main_OnCommand(40859, 0)
  assert(reaper.CountTracks(0) == 0, 'Expected an empty project tab')
  reaper.SetCurrentBPM(0, bpm, true)
end

local function render(name, duration)
  local project = reaper.EnumProjects(-1)
  local master = reaper.GetMasterTrack(project)
  reaper.SetMediaTrackInfo_Value(master, 'D_VOL', 1)
  local compressor = add_fx(master, 'VST: ReaComp (Cockos)')
  physical(master, compressor, 0, -16)
  physical(master, compressor, 1, 2)
  physical(master, compressor, 2, 8)
  physical(master, compressor, 3, 65)
  physical(master, compressor, 14, 4)
  for field, value in pairs({RENDER_SRATE=48000, RENDER_CHANNELS=2,
    RENDER_SETTINGS=0, RENDER_BOUNDSFLAG=0, RENDER_STARTPOS=0,
    RENDER_ENDPOS=duration, RENDER_TAILFLAG=0, RENDER_NORMALIZE=0,
    RENDER_ADDTOPROJ=0}) do
    reaper.GetSetProjectInfo(project, field, value, true)
  end
  reaper.GetSetProjectInfo_String(project, 'RENDER_FILE', out, true)
  reaper.GetSetProjectInfo_String(project, 'RENDER_PATTERN', name, true)
  reaper.GetSetProjectInfo_String(project, 'RENDER_FORMAT', 'ZXZhdxgAAA==', true)
  reaper.GetSetProjectInfo_String(project, 'RENDER_FORMAT2', '', true)
  reaper.Main_SaveProjectEx(project, out .. '/' .. name .. '.rpp', 0)
  report('RENDER_START ' .. name)
  reaper.Main_OnCommand(42230, 0)
  report('RENDER_RETURNED ' .. name)
end

return {make_track=make_track, add_notes=add_notes, new_project=new_project, render=render}
end
