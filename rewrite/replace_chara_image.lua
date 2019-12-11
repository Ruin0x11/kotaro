package.path = package.path .. ";/home/ruin/build/elona-next/src/?.lua"
local raw = require("tools.layout.chip")
local images = {}

for i, v in ipairs(raw.chara) do
   local id = math.floor(v.x / 48) + (math.floor(v.y / 48) * 33)
   images[id] = "\"elona.chara_" .. string.gsub(v.output, ".*/([^/]*)%.png$", "%1") .. "\""
end

local builder = require("rewrite.lib.add_field_by_legacy_id")

return {
   execute = function(self, ast)
      builder(ast, "male_image", "male_image", images)
      builder(ast, "female_image", "female_image", images)
      return ast
   end
}
