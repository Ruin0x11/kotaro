local Codegen = require("kotaro.parser.codegen")

local base = {}

function base:new(field, to_field)
   return setmetatable({field=field,to_field=to_field}, {__index=base})
end

function base:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end
   return node:index("_id")
end

function base:execute(node)
   local target = node:index("base")
   if not target then
      target = Codegen.gen_constructor_expression({})
      node:modify_index("base", target)
   end

   for _, key in ipairs(node:keys()) do
      if string.match(key:string_value(), "^base_") then
         local expr = node:index(key)

         node:modify_index(key:string_value(), nil)
         target:modify_index(string.gsub(key:string_value(), "^base_(.+)", "%1"), expr)
         node:changed()
      end
   end
end

return {
   execute = function(self, ast, params)
      return ast:rewrite(base:new())
   end
}
