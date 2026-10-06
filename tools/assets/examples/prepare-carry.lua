-- Aseprite source authoring: supplied raster layers only, no drawn body parts.
local root = app.params.root
assert(root, "Pass --script-param root=PROJECT_PATH")
local body = app.open(root .. "/assets/explorers-unlit.png")
app.activeSprite = body
body:crop(0, 0, 512, 800)
app.command.SpriteSize { width=128, height=200, method="bilinear" }
body.layers[1].name = "P1 painted explorer"
local idol = app.open(root .. "/assets/relic.png")
app.activeSprite = idol
local cel = idol.cels[1]
local bounds = cel.image:shrinkBounds()
idol:crop(bounds.x + cel.position.x, bounds.y + cel.position.y, bounds.width, bounds.height)
app.command.SpriteSize { width=28, height=39, method="bilinear" }
local layer = body:newLayer()
layer.name = "Physical relic reference"
body:newCel(layer, body.frames[1], idol.cels[1].image, Point(16, 91))
app.activeSprite = body
body:saveAs(root .. "/assets/authored/explorer-p1-carry-reference-v1.aseprite")
body:saveCopyAs(root .. "/assets/authored/explorer-p1-carry-reference-v1.png")
idol:close()
body:close()
