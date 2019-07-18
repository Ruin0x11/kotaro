function table.keys(tbl)
   local arr = {}
   for k, _ in pairs(tbl) do
      arr[#arr+1] = k
   end
   return arr
end

local visitor = {}

function visitor.visit_node(v, node, visit)
   local child = node[2]

   while child do
      local r = visitor.visit(v, child)
      if r then return r end
      child = child.right
   end
end

function visitor.visit(v, node)
   local r

   v._cache = v._cache or {}
   if v._cache[node] then
      error(string.format("loop detected: %s %s", tostring(node), node:dump()))
   end
   v._cache[node] = true

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
