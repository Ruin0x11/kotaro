local add_field_by_legacy_id = {}

function add_field_by_legacy_id:new(legacy_id, field, items)
   return setmetatable({legacy_id = legacy_id, field = field, items = items}, {__index = add_field_by_legacy_id})
end
function add_field_by_legacy_id:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.legacy_id)
   if not target or target:type() ~= "expression" then
      return false
   end

   return self.items[target:evaluate()] ~= nil
end
function add_field_by_legacy_id:execute(node)
   local id = node:index(self.legacy_id):evaluate()
   local tbl = self.items[id]
   local Codegen = require("kotaro.parser.codegen")
   local expr = Codegen.gen_expression(tbl)
   node:modify_index(self.field, expr)
end

return function(ast, legacy_id, field, items)
   return ast:rewrite(add_field_by_legacy_id:new(legacy_id, field, items))
end
