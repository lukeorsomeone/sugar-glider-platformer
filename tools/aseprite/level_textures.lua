-- Generates the wood and gum bark textures (the rest come from bright_textures.lua).
-- Run:  Aseprite.exe -b --script-param dir=<output folder> --script level_textures.lua
-- Each texture is saved as <name>.aseprite (to touch up by hand) and <name>.png (for Godot).
-- grass, grass edge, stone cliff, water and leaves: see bright_textures.lua.

local dir = app.params["dir"]

local function rgb(r, g, b) return Color{ r = r, g = g, b = b } end

local function new(w, h)
  local spr = Sprite(w, h, ColorMode.RGB)
  return spr, spr.cels[1].image
end

-- drawPixel with wrap-around, so everything tiles seamlessly
local function put(img, x, y, c)
  img:drawPixel(x % img.width, y % img.height, c)
end

local function fill_noise(img, choices)
  -- choices: { {colour, weight}, ... }
  local total = 0
  for _, ch in ipairs(choices) do total = total + ch[2] end
  for y = 0, img.height - 1 do
    for x = 0, img.width - 1 do
      local n, acc = math.random() * total, 0
      for _, ch in ipairs(choices) do
        acc = acc + ch[2]
        if n <= acc then img:drawPixel(x, y, ch[1]); break end
      end
    end
  end
end

local function save(spr, name)
  spr:saveAs(dir .. "/" .. name .. ".aseprite")
  spr:saveCopyAs(dir .. "/" .. name .. ".png")
  print("saved " .. name)
end

-- shared palettes -----------------------------------------------------------
local G = { rgb(40,110,52), rgb(58,140,60), rgb(82,176,70), rgb(112,204,84), rgb(156,226,108) }
local D = { rgb(74,44,28), rgb(102,62,36), rgb(128,80,46), rgb(150,98,58), rgb(176,128,84) }

-- wood: branch platforms, grain runs horizontally (along the path) -------------
math.randomseed(13)
do
  local W = { rgb(92,56,34), rgb(122,78,44), rgb(150,100,58), rgb(178,128,78), rgb(206,160,104) }
  local spr, img = new(32, 32)
  for y = 0, 31 do
    local base = (y % 8 < 4) and W[3] or W[2]
    for x = 0, 31 do img:drawPixel(x, y, base) end
  end
  for line = 0, 7 do
    local y0 = line * 4 + math.random(0, 1)
    for x = 0, 31 do
      local y = y0 + math.floor(math.sin(x / 32 * math.pi * 2 * (1 + line % 2)) + 0.5)
      put(img, x, y, (line % 2 == 0) and W[4] or W[1])
    end
  end
  -- a knot
  local kx, ky = 20, 13
  for dy = -2, 2 do for dx = -3, 3 do
    if dx * dx / 9 + dy * dy / 4 <= 1 then put(img, kx + dx, ky + dy, W[1]) end
  end end
  put(img, kx, ky, W[5]); put(img, kx - 1, ky, W[4])
  save(spr, "wood")
end

-- gum_bark: pale eucalyptus trunk, vertical streaks and peeling patches --------
math.randomseed(14)
do
  local B = { rgb(150,140,128), rgb(186,176,160), rgb(214,204,186), rgb(234,226,208), rgb(200,170,150) }
  local spr, img = new(32, 32)
  for x = 0, 31 do
    local col = ({ B[3], B[3], B[2], B[4] })[math.random(1, 4)]
    for y = 0, 31 do
      local c = col
      if math.random() < 0.12 then c = B[2] end
      img:drawPixel(x, y, c)
    end
  end
  -- long thin cracks
  for i = 1, 6 do
    local x, y0, len = math.random(0, 31), math.random(0, 31), math.random(6, 16)
    for y = y0, y0 + len do put(img, x, y, B[1]) end
  end
  -- peeling patches (pinkish / bright)
  for i = 1, 5 do
    local cx, cy = math.random(0, 31), math.random(0, 31)
    local w, h = math.random(2, 4), math.random(4, 8)
    local c = (i % 2 == 0) and B[5] or B[4]
    for dy = -h, h do for dx = -w, w do
      if (dx * dx) / (w * w) + (dy * dy) / (h * h) <= 1 then put(img, cx + dx, cy + dy, c) end
    end end
    for dy = -h, h do put(img, cx - w - 1, cy + dy, B[1]) end
  end
  save(spr, "gum_bark")
end

