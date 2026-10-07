local root = assert(app.params.root, "Pass root=PROJECT_PATH")
local path = app.params.manifest or root .. "/.asset-work/characters/explorer-eight-way-v1/assembled/aseprite.json"
local file = assert(io.open(path, "r"))
local data = json.decode(file:read("*a"))
file:close()
local sprite = Sprite(data.canvas[1], data.canvas[2], ColorMode.RGB)
local layers = {}
for i, crew in ipairs(data.crew) do
  local layer = i == 1 and sprite.layers[1] or sprite:newLayer()
  layer.name = crew.name
  layer.isVisible = i == 1
  layers[i] = layer
end
for index=0,data.frames-1 do
  local frame = index == 0 and sprite.frames[1] or sprite:newEmptyFrame()
  for i, crew in ipairs(data.crew) do
    sprite:newCel(layers[i], frame, Image{fromFile=string.format("%s/%04d.png",crew.path,index)}, Point(0,0))
  end
end
for _, animation in ipairs(data.animations) do
  local first = animation.frames[1][1] + 1
  local last = animation.frames[#animation.frames][1] + 1
  sprite:newTag(first,last).name = animation.name
  for index=first,last do sprite.frames[index].duration = 1 / animation.fps end
end
sprite:saveAs(app.params.output or root .. "/assets/authored/explorer-eight-way-v1.aseprite")
sprite:close()
