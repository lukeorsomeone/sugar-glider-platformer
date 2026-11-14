-- Tile an image 2x2 and scale it up 8x for previewing.
local src = Image{ fromFile = app.params["in"] }
local w, h = src.width, src.height
local spr = Sprite(w*2, h*2, ColorMode.RGB)
local img = spr.cels[1].image
for ty=0,1 do for tx=0,1 do img:drawImage(src, Point(tx*w, ty*h)) end end
spr:resize(w*16, h*16)
spr:saveCopyAs(app.params["out"])
