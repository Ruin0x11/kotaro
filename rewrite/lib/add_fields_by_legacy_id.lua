local Codegen = require("kotaro.parser.codegen")

local add_fields_by_legacy_id = {}

function add_fields_by_legacy_id:new(legacy_id, items)
   return setmetatable({legacy_id = legacy_id, items = items}, {__index = add_fields_by_legacy_id})
end
function add_fields_by_legacy_id:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.legacy_id)
   if not target or target:type() ~= "expression" then
      return false
   end

   return self.items[target:evaluate()] ~= nil
end
function add_fields_by_legacy_id:execute(node)
   local id = node:index(self.legacy_id):evaluate()
   local tbl = self.items[id]

   for field, value in pairs(tbl) do
      local expr = Codegen.gen_expression(value)
      node:modify_index(field, expr)
   end
end

return function(ast, legacy_id, items)
   return ast:rewrite(add_fields_by_legacy_id:new(legacy_id, items))
end
