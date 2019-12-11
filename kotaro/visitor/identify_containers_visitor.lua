local visitor = require("kotaro.visitor")

local identify_containers_visitor = {}

function identify_containers_visitor:new()
   return setmetatable({ scopes = {} }, { __index = identify_containers_visitor })
end

function identify_containers_visitor:visit_leaf(node)
end

function identify_containers_visitor:visit_node(node, visit)
   if node:type() == "constructor_expression" then
      for _, child in ipairs(node:children()) do
         child:first_leaf().opening_bracket = node:first_leaf()
      end
   end
   if node:type() == "function_params_and_body" then
      node[4].is_function_start = true
   end
   if node:type() == "expression" then
      if node:is_unary() then
         node:operator().is_unary_op = true
      elseif node:is_binary() then
         node:operator().is_binary_op = true
      end
   end
   visit(self, node, visit)
end

return identify_containers_visitor
