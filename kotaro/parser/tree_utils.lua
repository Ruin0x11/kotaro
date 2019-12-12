local visitor = require("kotaro.visitor")
local print_visitor = require("kotaro.visitor.print_visitor")
local utils = require("kotaro.utils")
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

local OPEN_SYMBOLS = utils.set {
   "(", "[", "{", "do", "repeat", "then", "else"
}

local CLOSE_SYMBOLS = utils.set {
   ")", "]", "}", "end", "until"
}

function tree_utils.opens_scope(token)
   return OPEN_SYMBOLS[token.value]
end

function tree_utils.closes_scope(token)
   return CLOSE_SYMBOLS[token.value]
end

local BLOCKS = utils.set {
   "if_block",
   "do_block",
   "while_block",
   "for_block",
   "function_declaration",
   "function_expression",
   "repeat_block",
}

function tree_utils.is_block(node)
   return BLOCKS[node:type()]
end

return tree_utils
