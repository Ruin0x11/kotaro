local group_fields = {}

function group_fields:new(field, items, invert)
   return setmetatable({field = field, items = items, invert = invert}, {__index = group_fields})
end

function group_fields:applies(child)
   if child:type() ~= "key_value_pair" then
      return false
   end

   for _, field in ipairs(self.items) do
      if child.key then
         local found = child:key():raw_value() == field
         if self.invert and found then
            return false
         elseif not self.invert and found then
            return true
         end
      end
   end

   if self.invert then
      return true
   else
      return false
   end
end

function group_fields:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   if not node:index("_id") then
      return false
   end

   for _, child in node:iter_children() do
      if self:applies(child) then
         return true
      end
   end

   return false
end

function group_fields:execute(node)
   local Codegen = require("kotaro.parser.codegen")

   local stmts = {}
   local remove = {}

   for i, child in node:iter_children() do
      if self:applies(child) then
         remove[#remove+1] = i
      end
   end

   local o = 0
   for _, v in ipairs(remove) do
      local s = node:remove(v+o)
      stmts[#stmts+1] = s
      o = o - 1
   end

   local target = Codegen.gen_constructor_expression(stmts)

   node:modify_index(self.field, target)
   node:changed()
end

return function(ast, field, items, invert)
   return ast:rewrite(group_fields:new(field, items, invert))
end
