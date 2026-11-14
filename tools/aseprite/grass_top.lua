-- 32x32 tiling grass-top texture in a small bright palette.
local out = app.params["out"]
local spr = Sprite(32, 32, ColorMode.RGB)
local img = spr.cels[1].image
local pal = {
  Color{r=58,g=140,b=60}, Color{r=82,g=176,b=70}, Color{r=112,g=204,b=84},
  Color{r=156,g=226,b=108}, Color{r=40,g=110,b=52},
}
math.randomseed(7)
for y=0,31 do for x=0,31 do
  local n = math.random()
  local c = n < 0.55 and pal[2] or (n < 0.8 and pal[3] or (n < 0.93 and pal[1] or pal[5]))
  img:drawPixel(x, y, c)
end end
-- grass blades: short light strokes with a dark root (wrap around edges so it tiles)
for i=1,40 do
  local x, y = math.random(0,31), math.random(0,31)
  img:drawPixel(x, y, pal[4]); img:drawPixel(x, (y+1)%32, pal[3]); img:drawPixel(x, (y+2)%32, pal[1])
end
-- a few flowers
for i=1,4 do
  local x, y = math.random(1,30), math.random(1,30)
  local petal = (i % 2 == 0) and Color{r=255,g=236,b=110} or Color{r=255,g=150,b=190}
  img:drawPixel(x-1,y,petal); img:drawPixel(x+1,y,petal); img:drawPixel(x,y-1,petal); img:drawPixel(x,y+1,petal)
  img:drawPixel(x,y,Color{r=255,g=255,b=240})
end
spr:saveAs(out .. ".aseprite")
spr:saveCopyAs(out .. ".png")
print("saved " .. out)
