package.path = package.path .. ";/home/ruin/build/elona-next/src/?.lua"
local raw = require("tools.layout.chip")
local images = {}

for i, v in ipairs(raw.area) do
   local id = math.floor(v.x / 48) + (math.floor(v.y / 48) * 33)
   images[id] = "\"elona." .. string.gsub(v.output, ".*/([^/]*)%.png$", "%1") .. "\""
end

local add_by = require("rewrite.lib.add_field_by_legacy_id")
local invert = require("rewrite.lib.invert_field")
local rename = require("rewrite.lib.rename_field")
local remove = require("rewrite.lib.remove_field")
local move_to_table = require("rewrite.lib.move_field_to_table")
local group_fields = require("rewrite.lib.group_fields")

return {
   execute = function(self, ast)
      rename(ast, "id", "_id")
      rename(ast, "legacy_id", "elona_id")
      remove(ast, "outer_map")
      remove(ast, "outer_map_position")
      invert(ast, "is_indoor")
      rename(ast, "is_indoor", "is_outdoor")
      rename(ast, "is_generated_every_time", "has_anchored_npcs")
      invert(ast, "has_anchored_npcs")
      rename(ast, "base_turn_cost", "turn_cost")
      rename(ast, "map_type", "types")
      move_to_table(ast, "types")
      rename(ast, "deepest_level", "deepest_dungeon_level")
      remove(ast, "tile_set")
      group_fields(ast, "copy", {"_id", "elona_id", "appearance"}, true)
      add_by(ast, "appearance", "image", images)
      remove(ast, "appearance")
      return ast
   end
}
