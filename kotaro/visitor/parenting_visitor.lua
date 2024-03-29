local visitor = require("kotaro.visitor")

local parenting_visitor = {}

function parenting_visitor:new(parent)
   return setmetatable({ current_parent = parent }, { __index = parenting_visitor })
end

function parenting_visitor:visit_leaf(node)
   node.parent = self.current_parent
end

function parenting_visitor:visit_node(node, visit)
   node.parent = self.current_parent

   local before = self.current_parent
   self.current_parent = node
   for i=2, #node do
      local prev_child = node[i-1]
      local child = node[i]
      local next_child = node[i+1]

      child.left = nil
      child.right = nil

      if type(prev_child) == "table" then
         child.left = prev_child
         prev_child.right = child
      end
      if type(next_child) == "table" then
         child.right = next_child
         next_child.left = child
      end

      visitor.visit(self, child, visit)
   end
   self.current_parent = before
end

return parenting_visitor
