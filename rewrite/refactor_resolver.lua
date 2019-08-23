local refactor_resolver = {}

local function is_resolver(node)
   if node:type() ~= "expression" then
      return false
   end

   local it = node:primary_expression()

   if it:type() ~= "suffixed_expression" then
      return false
   end

   return it:full_name() == "Resolver.make"
end

local pred = function(node) return node:type() == "constructor_expression" and node:index("skills") end

function refactor_resolver:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local skills = node:index("skills")
   if not skills then
      return false
   end

   return is_resolver(skills) and skills:find_child(pred)
end

function refactor_resolver:execute(node)
   local skills = node:index("skills")
   local cons = skills:find_child(pred):index("skills")
   node:modify_index("skills", cons)
   node:changed()
end

return {
   execute = function(self, ast)
      return ast:rewrite(refactor_resolver)
   end
}
