local visitors = require("yalf.visitor.visitors")
local visitor = visitors.visitor
local print_visitor = visitors.print_visitor
local tree_utils = {}

function tree_utils.dump(node, stream)
   visitor.visit(print_visitor:new(stream), node)
end

return tree_utils
