function table.keys(tbl)
   local arr = {}
   for k, _ in pairs(tbl) do
      arr[#arr+1] = k
   end
   return arr
end

local visitor = {}

function visitor.visit_node(v, node, visit)
   for _, child in node:iter_rest() do
      local r = visitor.visit(v, child)
      if r then return r end
   end
end

function visitor.visit(v, node)
   local r

   if node[1] == "leaf" then
      r = v:visit_leaf(node)
   elseif type(node[1]) == "string" then
      r = v:visit_node(node, visitor.visit_node)
   else
      error("invalid node ".. require"inspect"(node))
   end

   if r then
      return r
   end
end


return visitor
