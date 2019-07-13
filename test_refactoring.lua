local ex = {}

function ex:applies_to(node)
   if node:type() ~= "function_declaration" then
      return false
   end

   if node:is_local() then
      return false
   end

   print(node:declarer())
   print(node:full_name())
   print(node:arguments():get_nth(1))
   return node:declarer() == "ex"
end

function ex:execute(node)
   node:set_declarer("Asdfg")
end

local ex2 = {}

function ex2:applies_to(node)
   if node.type ~= "function_declaration" then
      return false
   end
   --return suff_to_name(node.children[2]) == "ex:applies_to"
   return false
end

function ex2:execute(node)
   local body = node.children[3].children[4]
   local take = {}
   for i, statement in ipairs(body.children) do
      if statement.type == "call_statement" then
         take[#take+1] = i
      end
   end

   local loc = body.parent.parent.prev_node

   local i = 0
   for _, ind in ipairs(take) do
      local c = body:remove_child(ind + i)
      loc:append_child(c)
      i = i - 1
   end
end

return {ex, ex2}
