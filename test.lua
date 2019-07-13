hotload = require("hotload")
hotload.hook_global_require()

stopwatch = require("stopwatch")
visitors = require("yalf.visitor.visitors")
visitor = visitors.visitor
tree_utils = require("yalf.parser.tree_utils")

function file2src(file)
   file = file or "test_refactoring.lua"

   local inf = io.open(file, 'r')
   if not inf then --comment
      print("Failed to open `"..file.."` for reading")
      return
   end
   local s = inf:read('*all')
   inf:close()

   return s
end

function src2cst(code)
   local sw = stopwatch()

   local cst_parser = require("yalf.parser.cst_parser")
   local a, new = cst_parser(code):parse()
   assert(a)

   sw:p("parse")

   return new
end

function cst2src(cst)
   local string_io = {
      stream = "",
      write = function(self, s)
         self.stream = self.stream .. s
      end
   }
   local v = visitors.code_convert_visitor:new(string_io)
   visitor.visit(v, cst)
   return string_io.stream
end

function parse_compare(file)
   local orig = file2src(file)
   local cst = src2cst(orig)

   local result = cst2src(cst)

   if result ~= orig then
      local f1 = io.open("/tmp/f1", "w")
      local f2 = io.open("/tmp/f2", "w")
      f1:write(orig)
      f2:write(result)
      f1:close()
      f2:close()

      os.execute("diff /tmp/f1 /tmp/f2 --color=always")
   end
end

function file2cst(file)
   return src2cst(file2src(file))
end

function dump(cst)
   tree_utils.dump(cst)
end

function refactor_file(file, refs)
   local cst = file2cst(file)

   visitor.visit(visitors.refactoring_visitor:new(refs or require("test_refactoring")), cst)

   return cst
end

Codegen = require("yalf.parser.codegen")
inspect = require("inspect")
cst = file2cst()

move_to_inner_table = { order = "preorder" }
function move_to_inner_table:new(keys, target)
   return setmetatable({keys = keys, target = target}, {__index = move_to_inner_table})
end
function move_to_inner_table:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.target)
   if target and
      (target:type() ~= "expression" or
          target:primary_expression():type() ~= "constructor_expression")
   then
      return false
   end

   return true
end
function move_to_inner_table:execute(node)
   local target = node:index(self.target)

   for _, k in ipairs(self.keys) do
      local val = node:index(k)

      if val then
         if target == nil then
            target = node:modify_index(self.target, Codegen.gen_constructor_expression({}))
         end

         node:modify_index(k, nil)

         target:primary_expression():modify_index(k, val)
      end
   end
end
