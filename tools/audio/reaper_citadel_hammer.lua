-- Iron Citadel mortar hammer: launch "thoomp" from the core and the slam on the marked circle.
-- Renders 24-bit sources; level to the shared -16 dB short-term target afterwards.
-- Output folder: $SFX_OUT if set, otherwise docs/audio/production_se/citadel_hammer.
local script = debug.getinfo(1, 'S').source:sub(2):gsub('\\', '/')
local root = assert(script:match('^(.*)/tools/audio/[^/]+$'))
local out = (os.getenv('SFX_OUT') or (root .. '/docs/audio/production_se/citadel_hammer')):gsub('\\', '/')
reaper.RecursiveCreateDirectory(out, 0)
local log = assert(io.open(out .. '/render.txt', 'w'))
local function report(s) log:write(s .. '\n'); log:flush() end
local engine = dofile(root .. '/tools/audio/reaper_engine.lua')(out, log)

-- Layer: {track, base voice, MIDI note, level dB, start s, patch}. Notes run to the cue end.
local cues = {
  {'citadel_hammer_launch', .48, {
    {'body', 'shock_body', 33, -12, 0, {bend=19, bendtime=.07, decay=.16, filter=1600}},
    {'thump', 'shock_noise', 40, -17, 0, {algorithm=.5, bend=12, bendtime=.05, decay=.09, filter=1800}},
    {'whoosh', 'scatter_noise', 86, -11, .04, {bend=-24, bendtime=.30, attack=.12, decay=.30, filter=3200}},
    {'flight', 'lance_tone', 76, -16, .05, {bend=-19, bendtime=.30, attack=.08, decay=.30, filter=2600}},
  }},
  {'citadel_hammer_impact', .58, {
    {'body', 'shock_body', 28, -12, 0, {bend=24, bendtime=.10, decay=.26, filter=1400}},
    {'punch', 'kill_tone', 40, -17, 0, {duty=1, bend=14, bendtime=.08, decay=.10, filter=2000}},
    {'clank', 'hit_tone', 79, -8, 0, {duty=.5, bend=2, bendtime=.015, decay=.12, filter=4200}},
    {'clank_hi', 'hit_tone', 85, -13, 0, {duty=0, decay=.08, filter=4200}},
    {'bounce', 'hit_tone', 79, -16, .15, {duty=.5, decay=.06, filter=3800}},
    {'edge', 'shot_edge', 90, -14, 0, {algorithm=1, decay=.02}},
    {'debris', 'scatter_noise', 64, -9, .01, {bend=10, bendtime=.40, decay=.50, filter=2400}},
  }},
}

local function main()
  for _, cue in ipairs(cues) do
    local name, length = cue[1], cue[2]
    engine.new_project(120)
    for _, layer in ipairs(cue[3]) do
      local track = engine.make_track(name .. ' / ' .. layer[1], layer[2], layer[4], 0, false, layer[6])
      engine.add_notes(track, {{layer[5], layer[3], length - layer[5] - .02, 115}}, 1, length, 1)
    end
    engine.render(name, length)
  end
  report('COMPLETE')
end
local ok, err = xpcall(main, debug.traceback)
if not ok then report('FAIL: ' .. tostring(err)) end
log:close()
