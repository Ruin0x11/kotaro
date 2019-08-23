local items = {
   [430] = 5,
   [431] = 8,
   [502] = 7,
   [480] = 20,
   [421] = 15,
   [603] = 20,
   [615] = 5,
   [559] = 10,
   [516] = 3,
   [616] = 18,
   [623] = 85,
   [624] = 25,
   [505] = 12,
   [625] = 11,
   [626] = 30,
   [627] = 55,
   [56] = 65,
   [742] = 72,
   [760] = 94,
}

local builder = require("rewrite.lib.add_field_by_legacy_id")

return {
   execute = function(self, ast)
      return builder(ast, "elona_id", "medal_value", items)
   end
}
