local move_field_to_table = {}

function move_field_to_table:new(field)
   return setmetatable({field = field}, {__index = move_field_to_table})
end
function move_field_to_table:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.field)
   if not target or target:type() ~= "expression" then
      return false
   end

   return true
end
function move_field_to_table:execute(node)
   local it = node:index(self.field):evaluate()
   local Codegen = require("kotaro.parser.codegen")
   local expr = Codegen.gen_expression({ Codegen.gen_expression(Codegen.gen_string(it)) })
   node:modify_index(self.field, expr)
end

return function(ast, field, items)
   return ast:rewrite(move_field_to_table:new(field, items))
end
