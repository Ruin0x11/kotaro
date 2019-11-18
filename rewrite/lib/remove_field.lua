local remove_field = {}

function remove_field:new(old)
   return setmetatable({old = old}, {__index = remove_field})
end
function remove_field:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.old)
   if not target or target:type() ~= "expression" then
      return false
   end

   return true
end
function remove_field:execute(node)
   node:modify_index(self.old, nil)
end

return function(ast, old, items)
   return ast:rewrite(remove_field:new(old, items))
end
