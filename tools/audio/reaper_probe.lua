-- Run in REAPER: reaper.exe -nonewinst tools/audio/reaper_probe.lua
-- Creates a dedicated project tab; never modifies a pre-existing project.
local script = debug.getinfo(1, 'S').source:sub(2):gsub('\\', '/')
local root = assert(script:match('^(.*)/tools/audio/[^/]+$'))
local out = root .. '/docs/audio/probe'
reaper.RecursiveCreateDirectory(out, 0)
local log = assert(io.open(out .. '/probe.txt', 'w'))
local function report(s) log:write(s .. '\n'); log:flush() end
local function main()
  report('REAPER ' .. reaper.GetAppVersion())
  report('new_tab_action=' .. reaper.kbd_getTextFromCmd(40859, 0))
  report('render_action=' .. reaper.kbd_getTextFromCmd(42230, 0))
  reaper.Main_OnCommand(40859, 0)
  local project = reaper.EnumProjects(-1)
  assert(reaper.CountTracks(project) == 0, 'Probe requires a new empty tab')
  reaper.InsertTrackAtIndex(0, true)
  local track = reaper.GetTrack(project, 0)
  reaper.GetSetMediaTrackInfo_String(track, 'P_NAME', 'Chip synthesis probe', true)
  reaper.SetMediaTrackInfo_Value(track, 'D_VOL', 0.15)
  local fx = reaper.TrackFX_AddByName(track, 'VST3i: Magical 8bit Plug 2 (Ymck)', false, -1)
  assert(fx >= 0, 'Magical 8bit Plug 2 failed to load')
  local _, name = reaper.TrackFX_GetFXName(track, fx, '')
  report('instrument=' .. name)
  for i = 0, math.min(27, reaper.TrackFX_GetNumParams(track, fx) - 1) do
    local _, param = reaper.TrackFX_GetParamName(track, fx, i, '')
    local value, lo, hi = reaper.TrackFX_GetParam(track, fx, i)
    local _, formatted = reaper.TrackFX_GetFormattedParamValue(track, fx, i, '')
    report(string.format('%d\t%s\t%.9g\t%.9g\t%.9g\t%s', i, param, value, lo, hi, formatted))
  end
  local item = reaper.CreateNewMIDIItemInProj(track, 0, 2.0, false)
  local take = reaper.GetActiveTake(item)
  for n = 0, 3 do
    local begin = reaper.MIDI_GetPPQPosFromProjTime(take, n * 0.4)
    local finish = reaper.MIDI_GetPPQPosFromProjTime(take, n * 0.4 + 0.25)
    reaper.MIDI_InsertNote(take, false, false, begin, finish, 0, 48+n*3, 90, true)
  end
  reaper.MIDI_Sort(take)
  reaper.GetSetProjectInfo(project, 'RENDER_SRATE', 48000, true)
  reaper.GetSetProjectInfo(project, 'RENDER_CHANNELS', 2, true)
  reaper.GetSetProjectInfo(project, 'RENDER_SETTINGS', 0, true)
  reaper.GetSetProjectInfo(project, 'RENDER_BOUNDSFLAG', 0, true)
  reaper.GetSetProjectInfo(project, 'RENDER_STARTPOS', 0, true)
  reaper.GetSetProjectInfo(project, 'RENDER_ENDPOS', 2, true)
  reaper.GetSetProjectInfo(project, 'RENDER_TAILFLAG', 0, true)
  reaper.GetSetProjectInfo_String(project, 'RENDER_FILE', out, true)
  reaper.GetSetProjectInfo_String(project, 'RENDER_PATTERN', 'chip_probe', true)
  -- WAV, 24-bit PCM, using REAPER's base64 render-format representation.
  reaper.GetSetProjectInfo_String(project, 'RENDER_FORMAT', 'ZXZhdxgAAA==', true)
  reaper.Main_SaveProjectEx(project, out .. '/chip_probe.rpp', 0)
  reaper.UpdateArrange()
  report('PROJECT_READY')
  reaper.Main_OnCommand(42230, 0)
  report('RENDER_ACTION_RETURNED')
end
local ok, err = xpcall(main, debug.traceback)
if not ok then report('FAIL: ' .. tostring(err)) end
log:close()
