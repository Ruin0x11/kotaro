local cst_parser = require("kotaro.parser.cst_parser")
local inspect = require("inspect")

local function parse(src)
   local ok, cst = assert(cst_parser(src, "test"):parse())

   cst:changed()

   return cst
end

describe("cst_parser",
         function()
            assert:set_parameter("TableFormatLevel", 2)

            it("parses nothing", function()
                  local ast = parse("")
                  assert.same("program", ast:type())
                  assert.same(1, #ast:children())

                  local root = ast:children()[1]
                  assert.same("statement_list", root:type())
                  assert.same(0, #root:children())
            end)

            it("parses assignment", function()
                  local node = parse("x = 1"):first_child()

                  assert.same("statement_list", node:type())
                  assert.same(1, #node:children())

                  local expr = node:first_child()
                  assert.same("assignment_statement", expr:type())
                  assert.same(false, expr:is_local())

                  assert.is_not_nil(expr:lhs())
                  assert.same("x", expr:lhs():raw_value())
                  assert.is_not_nil(expr:rhs())
                  assert.same("1", expr:rhs():raw_value())
            end)

            it("parses local assignment", function()
                  local node = parse("local x = 1"):first_child()

                  assert.same("statement_list", node:type())
                  assert.same(1, #node:children())

                  local expr = node:first_child()
                  assert.same("assignment_statement", expr:type())
                  assert.same(true, expr:is_local())

                  assert.is_not_nil(expr:lhs())
                  assert.same("ident_list", expr:lhs():type())
                  assert.same("x", expr:lhs():raw_value())
                  assert.is_not_nil(expr:rhs())
                  assert.same("expression_list", expr:rhs():type())
                  assert.same("1", expr:rhs():raw_value())
            end)

            it("parses compound expression assignment", function()
                  local node = parse("x = 1 + 1"):first_child()

                  assert.same("statement_list", node:type())
                  assert.same(1, #node:children())

                  local expr = node:first_child()
                  assert.same("assignment_statement", expr:type())
                  assert.same(false, expr:is_local())

                  assert.is_not_nil(expr:lhs())
                  assert.same("ident_list", expr:lhs():type())
                  assert.same("x", expr:lhs():raw_value())
                  assert.is_not_nil(expr:rhs())

                  local rhs = expr:rhs():first_child()
                  assert.same("expression", rhs:type())
                  assert.same(3, #rhs:children())
            end)

            it("parses if block", function()
                  local node = parse("if true then x = 1 end"):first_child()

                  assert.same("statement_list", node:type())
                  assert.same(1, #node:children())

                  local if_block = node:first_child()
                  assert.same("if_block", if_block:type())
                  assert.same(2, #if_block:children())

                  local cond = if_block:children()[1]
                  assert.same("expression", cond:type())

                  local stmts = if_block:children()[2]
                  assert.same("statement_list", stmts:type())
                  assert.same(1, #stmts:children())
            end)

            it("parses if block with semicolon", function()
                  local node = parse("if true then x = 1; y = 2 end"):first_child()

                  assert.same("statement_list", node:type())
                  assert.same(1, #node:children())

                  local if_block = node:first_child()
                  assert.same("if_block", if_block:type())
                  assert.same(2, #if_block:children())

                  local cond = if_block:children()[1]
                  assert.same("expression", cond:type())

                  local stmts = if_block:children()[2]
                  assert.same("statement_list", stmts:type())
                  assert.same(3, #stmts:children())
            end)

            it("parses do block", function()
                  local node = parse("do x = 1 end"):first_child()

                  assert.same("statement_list", node:type())
                  assert.same(1, #node:children())

                  local do_block = node:first_child()
                  assert.same("do_block", do_block:type())
                  assert.same(1, #do_block:children())

                  local stmts = do_block:children()[1]
                  assert.same("statement_list", stmts:type())
            end)

            it("parses method on compound expression", function()
                  local node = parse("i = (a or b):method()"):first_child()

                  assert.same("statement_list", node:type())
                  assert.same(1, #node:children())

                  local assign = node:first_child()
                  assert.same("assignment_statement", assign:type())

                  local rhs = assign:rhs()
                  assert.same("expression_list", rhs:type())
            end)

         end)
