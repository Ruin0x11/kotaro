local visitors = require("yalf.visitor.visitors")
local visitor = visitors.visitor
local print_visitor = visitors.print_visitor
local ast_print_visitor = visitors.ast_print_visitor
local tree_utils = {}

function tree_utils.dump(node)
   visitor.visit(print_visitor:new(), node)
end

function tree_utils.dump_ast(node)
   visitor.visit(ast_print_visitor:new(), node)
end

return tree_utils
