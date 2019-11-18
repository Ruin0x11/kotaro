local invert_field = {}

function invert_field:new(field)
   return setmetatable({field = field}, {__index = invert_field})
end
function invert_field:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.field)
   if not target or target:type() ~= "expression" then
      return false
   end

   return true
end
function invert_field:execute(node)
   local it = node:index(self.field):evaluate()
   local Codegen = require("kotaro.parser.codegen")
   local expr = Codegen.gen_expression(not it)
   node:modify_index(self.field, expr)
end

return function(ast, field, items)
   return ast:rewrite(invert_field:new(field, items))
end
