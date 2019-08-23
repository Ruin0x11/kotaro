local colors = {
   [50] = { 150, 0, 0 },
   [51] = { 0, 0, 150 },
   [52] = { 150, 150, 0 },
   [59] = { 150, 0, 150 },
   [53] = { 100, 80, 80 },
   [55] = { 0, 150, 0 },
   [60] = { 150, 100, 100 },
   [57] = { 50, 100, 150 },
   [58] = { 100, 150, 50 },
   [54] = { 150, 100, 50 },
   [56] = { 150, 50, 0 },
}

local color_ids = {
   [50] = 3,
   [51] = 12,
   [52] = 5,
   [59] = 8,
   [53] = 4,
   [58] = 9,
   [57] = 11,
   [54] = 10,
   [55] = 2,
   [56] = 7,
   [63] = 2,
}

local builder = require("rewrite.lib.add_field_by_legacy_id")

return {
   execute = function(self, ast)
      builder(ast, "elona_id", "color", colors)
      builder(ast, "elona_id", "color_id", color_ids)
      return ast
   end
}
