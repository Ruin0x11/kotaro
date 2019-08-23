local enchantments = {}

local move_enchantments = {}

local function is_enchantment(node)
   if node:type() ~= "expression" then
      return false
   end

   local it = node:primary_expression()

   if it:type() ~= "constructor_expression" then
      return false
   end

   return it:index("id") and it:index("power")
end

function move_enchantments:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   if not node:index("_id") then
      return false
   end

   for _, child in node:iter_children() do
      if is_enchantment(child) then
         return true
      end
   end

   return false
end

function move_enchantments:execute(node)
   local Codegen = require("kotaro.parser.codegen")

   local stmts = {}
   local remove = {}

   for i, child in node:iter_children() do
      if is_enchantment(child) then
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

   node:modify_index("enchantments", target)
   node:changed()
end

function enchantments:execute(ast, params, opts)
   return ast:rewrite(move_enchantments)
end

return enchantments
