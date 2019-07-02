local class = require("pl.class")

local refactoring = {}

function refactoring:applies_to(node)
   return false
end

function refactoring:execute(node)
end

local exchange_refactoring = class(refactoring)

function exchange_refactoring:applies_to(node)
   local cond = node.children[2]
   return node.type == "if_block" and #cond.children == 3
end

local function swap_children(node, a, b)
   local i = node.children[a]
   local j = node.children[b]

   node.children[a] = j
   node.children[b] = i
end

function exchange_refactoring:execute(node)
   local cond = node.children[2]
   swap_children(cond, 1, 3)
end

return { exchange_refactoring = exchange_refactoring }
