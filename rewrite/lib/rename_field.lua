local rename_field = {}

function rename_field:new(old, field)
   return setmetatable({old = old, field = field}, {__index = rename_field})
end
function rename_field:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.old)
   if not target or target:type() ~= "expression" then
      return false
   end

   return true
end
function rename_field:execute(node)
   local it = node:index(self.old):clone()
   node:modify_index(self.old, it, self.field)
end

return function(ast, old, field, items)
   return ast:rewrite(rename_field:new(old, field, items))
end
