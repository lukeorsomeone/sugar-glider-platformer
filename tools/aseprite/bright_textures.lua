-- Bright, sunny textures: rounded-stone cliffs, vivid grass and sparkling water.
-- Run:  Aseprite.exe -b --script-param dir=<output folder> --script bright_textures.lua
-- Saves <name>.aseprite and <name>.png for each texture.

local dir = app.params["dir"]
local function rgb(r, g, b) return Color{ r = r, g = g, b = b } end
local function clamp(v) return math.max(0, math.min(255, math.floor(v + 0.5))) end
local function new(w, h) local s = Sprite(w, h, ColorMode.RGB); return s, s.cels[1].image end
local function put(img, x, y, c) img:drawPixel(x % img.width, y % img.height, c) end
local function save(spr, name)
  spr:saveAs(dir .. "/" .. name .. ".aseprite")
  spr:saveCopyAs(dir .. "/" .. name .. ".png")
  print("saved " .. name)
end

-- grass_top: vivid yellow-green with blades and flowers -------------------------
math.randomseed(21)
do
  local G = { rgb(70,160,46), rgb(100,196,54), rgb(136,220,70), rgb(186,240,102), rgb(54,132,42) }
  local spr, img = new(32, 32)
  for y = 0, 31 do for x = 0, 31 do
    local n = math.random()
    img:drawPixel(x, y, n < 0.5 and G[2] or (n < 0.8 and G[3] or (n < 0.93 and G[1] or G[4])))
  end end
  for i = 1, 36 do
    local x, y = math.random(0, 31), math.random(0, 31)
    put(img, x, y, G[4]); put(img, x, y + 1, G[3]); put(img, x, y + 2, G[5])
  end
  for i = 1, 4 do
    local x, y = math.random(1, 30), math.random(1, 30)
    local petal = (i % 2 == 0) and rgb(255,240,90) or rgb(255,130,180)
    put(img, x - 1, y, petal); put(img, x + 1, y, petal); put(img, x, y - 1, petal); put(img, x, y + 1, petal)
    put(img, x, y, rgb(255,255,240))
  end
  save(spr, "grass_top")
end

-- grass_lip (32x16): bright grass fringe hanging over stone ----------------------
-- stone_cliff: big rounded stones with dark gaps (tiling Voronoi) ----------------
local function stone_image(w, h, seed, nseeds)
  math.randomseed(seed)
  local seeds = {}
  for i = 1, nseeds do
    local base = ({ {214,196,160}, {196,182,150}, {226,210,176}, {180,170,146}, {204,188,170} })[math.random(1, 5)]
    seeds[i] = { x = math.random() * w, y = math.random() * h, c = base }
  end
  local spr, img = new(w, h)
  for y = 0, h - 1 do for x = 0, w - 1 do
    local d1, d2, best = 1e9, 1e9, nil
    for _, s in ipairs(seeds) do
      for oy = -1, 1 do for ox = -1, 1 do       -- wrap so it tiles
        local dx, dy = x + 0.5 - (s.x + ox * w), y + 0.5 - (s.y + oy * h)
        local d = math.sqrt(dx * dx + dy * dy)
        if d < d1 then d2 = d1; d1 = d; best = { s = s, dx = dx, dy = dy } elseif d < d2 then d2 = d end
      end end
    end
    local c
    if d2 - d1 < 1.3 then
      c = rgb(78, 66, 56)                         -- mortar / gap
    else
      -- light from the top-left so each stone looks rounded
      local shade = 1.0 - (best.dx + best.dy) * 0.035
      if d2 - d1 < 2.4 then shade = shade * 0.82 end
      local b = best.s.c
      c = rgb(clamp(b[1] * shade), clamp(b[2] * shade), clamp(b[3] * shade))
    end
    img:drawPixel(x, y, c)
  end end
  -- little moss specks
  for i = 1, 6 do put(img, math.random(0, w - 1), math.random(0, h - 1), rgb(120,170,80)) end
  return spr, img
end

do
  local spr = stone_image(32, 32, 22, 7)
  save(spr, "stone_cliff")
end

math.randomseed(23)
do
  local G = { rgb(54,132,42), rgb(100,196,54), rgb(136,220,70), rgb(186,240,102) }
  local spr, img = stone_image(32, 16, 24, 4)
  for x = 0, 31 do
    local len = 5 + math.random(0, 4) + ((x % 3 == 0) and 2 or 0)
    for y = 0, len do
      local c = (y >= len - 1) and G[1] or ((math.random() < 0.6) and G[3] or G[2])
      if y <= 1 and math.random() < 0.5 then c = G[4] end
      put(img, x, y, c)
    end
    put(img, x, len + 1, rgb(90, 80, 64))
  end
  save(spr, "grass_lip")
end

-- water: bright blue with light wave squiggles and sparkles ----------------------
math.randomseed(25)
do
  local spr, img = new(32, 32)
  for y = 0, 31 do for x = 0, 31 do
    img:drawPixel(x, y, (math.random() < 0.85) and rgb(46,150,236) or rgb(40,134,222))
  end end
  for i = 1, 10 do
    local x, y = math.random(0, 31), math.random(0, 31)
    for k = 0, 4 do put(img, x + k, y + ((k == 0 or k == 4) and 1 or 0), rgb(100,186,250)) end
  end
  for i = 1, 2 do put(img, math.random(0, 31), math.random(0, 31), rgb(220,244,255)) end
  save(spr, "water")
end

-- leaves: brighter, sunnier canopy ------------------------------------------------
math.randomseed(26)
do
  local L = { rgb(46,120,50), rgb(66,156,60), rgb(96,192,72), rgb(140,222,92), rgb(196,244,130) }
  local spr, img = new(32, 32)
  for y = 0, 31 do for x = 0, 31 do img:drawPixel(x, y, (math.random() < 0.6) and L[1] or L[2]) end end
  for i = 1, 70 do
    local x, y = math.random(0, 31), math.random(0, 31)
    local c = ({ L[2], L[3], L[3], L[4] })[math.random(1, 4)]
    put(img, x, y, c); put(img, x + 1, y, c); put(img, x + 1, y - 1, c); put(img, x + 2, y - 1, c)
    put(img, x + 2, y - 2, L[5]); put(img, x, y + 1, L[1])
  end
  save(spr, "leaves")
end
