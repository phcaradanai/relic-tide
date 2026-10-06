-- Preserve the existing six real leg poses and their authored cell origins.
local root = assert(app.params.root, "Pass root=PROJECT_PATH")
local input = root .. "/.asset-work/carry-study/"
local file = assert(io.open(input .. "poses.json", "r"))
local poses = json.decode(file:read("*a"))
file:close()
local idol = app.open(root .. "/assets/relic.png")
local cropVisible = dofile(root .. "/tools/assets/examples/visible-bounds.lua")
cropVisible(idol)
app.activeSprite = idol
app.command.SpriteSize { width=40, height=60, method="bilinear" }
local sprite = Sprite(288, 288, ColorMode.RGB)
local relicLayer = sprite.layers[1]
relicLayer.name = "Held relic"
local explorerLayer = sprite:newLayer()
explorerLayer.name = "Original painted walk poses"
local hands = {{236,126}, {240,132}, {235,132}, {236,126}, {231,131}, {235,134}}
for index, pose in ipairs(poses) do
  local frame = index == 1 and sprite.frames[1] or sprite:newEmptyFrame()
  frame.duration = 0.125
  sprite:newCel(explorerLayer, frame, Image{fromFile=input .. pose.file}, Point(pose.x+16, pose.y+16))
  sprite:newCel(relicLayer, frame, idol.cels[1].image, Point(hands[index][1]-4, hands[index][2]+14))
end
local tag = sprite:newTag(1, 6)
tag.name = "carry_e"
sprite:saveAs(root .. "/assets/authored/explorer-p1-carry-e-v2.aseprite")
sprite:close()
idol:close()
