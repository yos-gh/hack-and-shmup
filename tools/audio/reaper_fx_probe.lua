local script = debug.getinfo(1, 'S').source:sub(2):gsub('\\', '/')
local root = assert(script:match('^(.*)/tools/audio/[^/]+$'))
local out = root .. '/docs/audio/probe'
reaper.Main_OnCommand(40859, 0)
reaper.InsertTrackAtIndex(0, true)
local track = reaper.GetTrack(0, 0)
local log = assert(io.open(out .. '/effects.txt', 'w'))
for _, name in ipairs({'VST: ReaEQ (Cockos)', 'VST: ReaComp (Cockos)', 'VST: ReaDelay (Cockos)'}) do
  local fx = reaper.TrackFX_AddByName(track, name, false, -1)
  log:write(name .. ' fx=' .. fx .. '\n')
  if fx >= 0 then
    for i = 0, math.min(39, reaper.TrackFX_GetNumParams(track, fx) - 1) do
      local _, p = reaper.TrackFX_GetParamName(track, fx, i, '')
      local _, value = reaper.TrackFX_GetFormattedParamValue(track, fx, i, '')
      log:write(i .. '\t' .. p .. '\t' .. reaper.TrackFX_GetParamNormalized(track, fx, i) .. '\t' .. value .. '\n')
    end
  end
end
log:close()
reaper.Main_SaveProjectEx(0, out .. '/effect_probe.rpp', 0)
