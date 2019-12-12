local cst_parser = require("kotaro.parser.cst_parser")
local split_penalty_visitor = require("kotaro.visitor.split_penalty_visitor")
local visitor = require("kotaro.visitor")
local inspect = require("inspect")
local tree_utils = require("kotaro.parser.tree_utils")
local split_penalty = require("kotaro.split_penalty")

local function parse(src)
   local ok, cst = assert(cst_parser(src, "test"):parse())

   visitor.visit(split_penalty_visitor:new(), cst)

   return cst
end

function assert.check_penalties(ast, penalties)
   local actual = {}
   local cb = function(leaf)
      if leaf.leaf_type ~= "Eof" then
         actual[#actual+1] = { leaf.value, leaf.split_penalty }
      end
   end

   tree_utils.each_leaf(ast, cb)

   assert.same(penalties, actual)
end

describe("cst_parser",
         function()
            assert:set_parameter("TableFormatLevel", 2)

            it("penalties of comparison", function()
                  local ast = parse("function tbl:method() return a ~= nil end")
                  assert.check_penalties(ast,
                                         {
                                            {"function", nil},
                                            {"tbl",      split_penalty.unbreakable},
                                            {":",        split_penalty.unbreakable},
                                            {"method",   split_penalty.unbreakable},
                                            {"(",        split_penalty.unbreakable},
                                            {")",        split_penalty.unbreakable},
                                            {"return",   nil},
                                            {"a",        5000},
                                            {"~=",       1300},
                                            {"nil",      2000},
                                            {"end",      nil},
                                         })
            end)

            it("penalties of function declaration", function()
                  local ast = parse("function tbl:method() return 1 end")
                  assert.check_penalties(ast,
                                         {
                                            {"function", nil},
                                            {"tbl",      split_penalty.unbreakable},
                                            {":",        split_penalty.unbreakable},
                                            {"method",   split_penalty.unbreakable},
                                            {"(",        split_penalty.unbreakable},
                                            {")",        split_penalty.unbreakable},
                                            {"return",   nil},
                                            {"1",        5000},
                                            {"end",      nil},
                                         })
            end)

            it("penalties of call expression", function()
                  local ast = parse("tbl.method()")
                  assert.check_penalties(ast,
                                         {
                                            {"tbl",     nil},
                                            {".",       split_penalty.together},
                                            {"method",  split_penalty.unbreakable},
                                            {"(",       split_penalty.unbreakable},
                                            {")",       split_penalty.unbreakable},
                                         })
            end)

            it("penalties of method call expression", function()
                  local ast = parse("tbl:method()")
                  assert.check_penalties(ast,
                                         {
                                            {"tbl",     nil},
                                            {":",       split_penalty.together},
                                            {"method",  split_penalty.unbreakable},
                                            {"(",       split_penalty.unbreakable},
                                            {")",       split_penalty.unbreakable},
                                         })
            end)

            it("penalties of if block", function()
                  local ast = parse("if a ~= nil then return true elseif b < 2 then return false else return 1 end")
                  assert.check_penalties(ast,
                                         {
                                            {"if",      nil},
                                            {"a",       1002000},
                                            {"~=",      1300},
                                            {"nil",     2000},
                                            {"then",    split_penalty.unbreakable},
                                            {"return",  nil},
                                            {"true",    5000},
                                            {"elseif",  split_penalty.strongly_connected},
                                            {"b",       1002000},
                                            {"<",       1300},
                                            {"2",       2000},
                                            {"then",    split_penalty.unbreakable},
                                            {"return",  nil},
                                            {"false",   5000},
                                            {"else",    split_penalty.strongly_connected},
                                            {"return",  nil},
                                            {"1",       5000},
                                            {"end",     split_penalty.strongly_connected},
                                         })
            end)
         end)
