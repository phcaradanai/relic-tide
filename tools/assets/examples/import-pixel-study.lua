-- Preserve all nine frames of the reviewed API result at native resolution.
local root = assert(app.params.root, "Pass root=PROJECT_PATH")
local sprite = Sprite(216, 216, ColorMode.RGB)
sprite.layers[1].name = "PixelLab candidate (all returned frames)"
for index=1,9 do
  local frame = index == 1 and sprite.frames[1] or sprite:newEmptyFrame()
  frame.duration = 0.125
  local file = string.format("%s/.asset-work/pixel-quality-frames/frame_%03d.png", root, index-1)
  sprite:newCel(sprite.layers[1], frame, Image{fromFile=file}, Point(0,0))
end
sprite:newTag(1,9).name = "carry_e"
sprite:saveAs(root .. "/assets/authored/explorer-p1-carry-east-pixel-v2.aseprite")
sprite:saveCopyAs(root .. "/test-output/carry-pixel-study.gif")
sprite:close()
