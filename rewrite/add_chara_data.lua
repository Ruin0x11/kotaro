local items = {
   [2] = {
      eqweapon1 = 63,
   },
   [23] = {
      eqweapon1 = 64,
   },
   [28] = {
      eqweapon1 = 73,
   },
   [351] = {
      eqtwohand = 1,
      eqweapon1 = 232,
   },
   [33] = {
      eqweapon1 = 206,
   },
   [34] = {
      eqweapon1 = 1,
      eqrange = 207,
      eqammo = { 25001, 3 }
   },
   [141] = {
      eqweapon1 = 358,
   },
   [143] = {
      eqweapon1 = 359,
   },
   [144] = {
      eqweapon1 = 356,
   },
   [145] = {
      eqring1 = 357,
   },
   [336] = {
      eqtwohand = 1,
      eqweapon1 = 739,
   },
   [338] = {
      eqtwohand = 1,
      eqweapon1 = 739,
   },
   [339] = {
      eqtwohand = 1,
      eqweapon1 = 739,
   },
   [342] = {
      eqtwohand = 1,
      eqweapon1 = 739,
   },
   [340] = {
      eqtwohand = 1,
      eqweapon1 = 739,
   },
   [299] = {
      eqtwohand = 1,
   },
   [300] = {
      eqweapon1 = 695,
      eqtwohand = 1,
   },
   [309] = {
      eqmultiweapon = 2,
   },
   [310] = {
      eqmultiweapon = 266,
   },
   [311] = {
      eqmultiweapon = 224,
   },
   [307] = {
      eqweapon1 = 735,
      eqtwohand = 1,
   },
   [308] = {
      eqweapon1 = 735,
   },
   [50] = {
      eqtwohand = 1,
   },
   [90] = {
      eqtwohand = 1,
   },
   [151] = {
      eqtwohand = 1,
   },
   [156] = {
      eqtwohand = 1,
   },
   [303] = {
      eqtwohand = 1,
   },
   [163] = {
      eqrange = 210,
   },
   [170] = {
      eqrange = 210,
   },
   [177] = {
      eqweapon1 = 1,
      eqrange = 514,
      eqammo = { 25030, 3 }
   },
   [212] = {
      eqweapon1 = 56,
   },
   [301] = {
      eqtwohand = 1,
   },
   [317] = {
      eqweapon1 = 232,
      eqtwohand = 1,
   },
   [318] = {
      eqrange = { 496, 4 },
      eqammo = { 25020, 3 }
   }
}

local builder = require("rewrite.lib.add_fields_by_legacy_id")

return {
   execute = function(self, ast)
      return builder(ast, "elona_id", items)
   end
}
