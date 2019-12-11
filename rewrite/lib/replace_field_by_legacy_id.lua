local replace_field_by_legacy_id = {}

function replace_field_by_legacy_id:new(legacy_id, items)
   return setmetatable({legacy_id = legacy_id, items = items}, {__index = replace_field_by_legacy_id})
end
function replace_field_by_legacy_id:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.legacy_id)
   if not target or target:type() ~= "expression" then
      return false
   end

   return self.items[target:evaluate()] ~= nil
end
function replace_field_by_legacy_id:execute(node)
   local id = node:index(self.legacy_id):evaluate()
   local tbl = self.items[id]
   local Codegen = require("kotaro.parser.codegen")
   local expr = Codegen.gen_expression(tbl)
   node:modify_index(self.legacy_id, expr, nil)
end

return function(ast, legacy_id, items)
   return ast:rewrite(replace_field_by_legacy_id:new(legacy_id, items))
end
