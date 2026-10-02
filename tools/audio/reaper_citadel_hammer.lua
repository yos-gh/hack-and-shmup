-- Iron Citadel mortar hammer: launch "don" from the core, then the fall and slam on the marked circle.
-- Renders 24-bit sources; level to the shared -16 dB short-term target afterwards.
-- Output folder: $SFX_OUT if set, otherwise docs/audio/production_se/citadel_hammer.
local script = debug.getinfo(1, 'S').source:sub(2):gsub('\\', '/')
local root = assert(script:match('^(.*)/tools/audio/[^/]+$'))
local out = (os.getenv('SFX_OUT') or (root .. '/docs/audio/production_se/citadel_hammer')):gsub('\\', '/')
reaper.RecursiveCreateDirectory(out, 0)
local log = assert(io.open(out .. '/render.txt', 'w'))
local function report(s) log:write(s .. '\n'); log:flush() end
local engine = dofile(root .. '/tools/audio/reaper_engine.lua')(out, log)

-- Layer: {track, base voice, MIDI note, level dB, start s, patch[, note length s]}.
-- Notes run to the cue end unless a length is given.
-- Launch: a low firework-mortar "don" leads; the rising air is only a faint tail.
-- Impact: the hammer whistles down for LANDING seconds, then lands ("don" + "gashan").
-- Start the impact cue LANDING seconds before the hammer touches down.
local LANDING = .30
local cues = {
  {'citadel_hammer_launch', .48, {
    {'body', 'shock_body', 33, -8, 0, {bend=19, bendtime=.06, decay=.22, filter=1400}},
    {'boom', 'kick', 36, -11, 0, {decay=.16, filter=1400}},
    {'thump', 'shock_noise', 40, -14, 0, {algorithm=.5, bend=12, bendtime=.05, decay=.10, filter=1600}},
    {'whoosh', 'scatter_noise', 86, -24, .05, {bend=-24, bendtime=.30, attack=.08, decay=.22, filter=2600}},
    {'flight', 'lance_tone', 76, -31, .06, {bend=-19, bendtime=.30, attack=.06, decay=.22, filter=2200}},
  }},
  {'citadel_hammer_impact', LANDING + .50, {
    {'fall_air', 'scatter_noise', 74, -21, 0, {bend=12, bendtime=LANDING, attack=.20, decay=.6, filter=2600}, LANDING},
    {'fall_tone', 'lance_tone', 67, -24, 0, {bend=14, bendtime=LANDING, attack=.20, decay=.6, filter=2400}, LANDING},
    {'body', 'shock_body', 28, -9, LANDING, {bend=24, bendtime=.10, decay=.26, filter=1400}},
    {'boom', 'kick', 33, -11, LANDING, {decay=.16, filter=1400}},
    {'punch', 'kill_tone', 40, -17, LANDING, {duty=1, bend=14, bendtime=.08, decay=.10, filter=2000}},
    {'clank', 'hit_tone', 79, -8, LANDING, {duty=.5, bend=2, bendtime=.015, decay=.12, filter=4200}},
    {'clank_hi', 'hit_tone', 85, -13, LANDING, {duty=0, decay=.08, filter=4200}},
    {'bounce', 'hit_tone', 79, -16, LANDING + .15, {duty=.5, decay=.06, filter=3800}},
    {'edge', 'shot_edge', 90, -14, LANDING, {algorithm=1, decay=.02}},
    {'debris', 'scatter_noise', 64, -9, LANDING + .01, {bend=10, bendtime=.40, decay=.50, filter=2400}},
  }},
}

local function main()
  for _, cue in ipairs(cues) do
    local name, length = cue[1], cue[2]
    engine.new_project(120)
    for _, layer in ipairs(cue[3]) do
      local track = engine.make_track(name .. ' / ' .. layer[1], layer[2], layer[4], 0, false, layer[6])
      engine.add_notes(track, {{layer[5], layer[3], layer[7] or (length - layer[5] - .02), 115}}, 1, length, 1)
    end
    engine.render(name, length)
  end
  report('COMPLETE')
end
local ok, err = xpcall(main, debug.traceback)
if not ok then report('FAIL: ' .. tostring(err)) end
log:close()
