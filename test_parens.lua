local fun = require("fun")
local kotaro = require("kotaro")
local Codegen = require("kotaro.parser.codegen")

local siz = {}
function siz:new()
   return setmetatable({ siz = 0, order = "preorder" }, { __index = siz })
end
function siz:visit_leaf()
   self.siz = self.siz + 1
end
function siz:visit_node(node, visit)
   self.siz = self.siz + 1
   visit(self, node, visit)
end
local function getsize(cst)
   local s = siz:new()
   require("kotaro.visitor").visit(s, cst)
   return s.siz
end

local parenthesize = {}
function parenthesize:new(also_unary)
   return setmetatable({ order = "preorder", also_unary = also_unary }, { __index = parenthesize })
end
function parenthesize:applies_to(node)
   if node:type() == "expression" then
      return node.parent:type() == "expression" and
         (node:is_binary() or (self.also_unary and node:is_unary()))
   end

   if node:type() == "parenthesized_expression" then
      return node.parent:type() == "expression" and node.parent:is_binary()
   end

   return false
end
function parenthesize:execute(node)
   if node:type() == "expression" then
      local n = node:clone()
      local p = Codegen.gen_parenthesized_expression(n)
      node:replace_with(p)
      node:changed()
   elseif node:type() == "parenthesized_expression" then
   end
end

local s = kotaro.rewrite_file("test_precedence.lua", { parenthesize:new(true) })
print(s)
