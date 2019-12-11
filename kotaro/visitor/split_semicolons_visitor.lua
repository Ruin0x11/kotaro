local visitor = require("kotaro.visitor")

local split_semicolons_visitor = {}

function split_semicolons_visitor:new(parent)
   return setmetatable({}, { __index = split_semicolons_visitor })
end

function split_semicolons_visitor:visit_leaf(node)
end

function split_semicolons_visitor:visit_node(node, visit)
   if node:type() == "statement_list" then
   end
   visit(self, node, visit)
end

return split_semicolons_visitor
