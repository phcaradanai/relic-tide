-- Find the opaque subject, retaining two antialiased edge pixels.
-- Generated relic art has near-transparent dust far outside its silhouette.
return function(sprite)
  local cel = sprite.cels[1]
  local image = cel.image
  local left, top, right, bottom = image.width, image.height, -1, -1
  for pixel in image:pixels() do
    if app.pixelColor.rgbaA(pixel()) > 127 then
      left = math.min(left, pixel.x); right = math.max(right, pixel.x)
      top = math.min(top, pixel.y); bottom = math.max(bottom, pixel.y)
    end
  end
  assert(right >= left, "No visible raster subject")
  left = math.max(0, left-2); top = math.max(0, top-2)
  right = math.min(image.width-1, right+2); bottom = math.min(image.height-1, bottom+2)
  sprite:crop(left+cel.position.x, top+cel.position.y, right-left+1, bottom-top+1)
end
