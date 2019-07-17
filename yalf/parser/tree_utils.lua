local visitor = require("yalf.visitor")
local print_visitor = require("yalf.visitor.print_visitor")
local tree_utils = {}

function tree_utils.dump(node, stream)
   visitor.visit(print_visitor:new(stream), node)
end

local leaf_mutator_visitor = {}
function leaf_mutator_visitor:new(cb, ...)
   return setmetatable({ cb = cb, args = {...} }, { __index = leaf_mutator_visitor })
end
function leaf_mutator_visitor:visit_leaf(node)
   self.cb(node, unpack(self.args))
end
function leaf_mutator_visitor:visit_node(node, visit)
   visit(self, node, visit)
end

function tree_utils.each_leaf(node, cb, ...)
   visitor.visit(leaf_mutator_visitor:new(cb, ...), node)
end

return tree_utils
