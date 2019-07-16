hotload = require("hotload")
hotload.hook_global_require()

stopwatch = require("stopwatch")
visitors = require("yalf.visitor.visitors")
visitor = visitors.visitor
tree_utils = require("yalf.parser.tree_utils")

local sw = stopwatch()

function file2src(file)
   file = file or "test_refactoring.lua"

   local inf = io.open(file, 'r')
   if not inf then
      print("Failed to open `"..file.."` for reading")
      return
   end
   local s = inf:read('*all')
   inf:close()

   return s
end

function cst2file(cst, file)
   assert(file)

   local inf = io.open(file, 'w')
   visitor.visit(visitors.code_convert_visitor:new(inf), cst)
   inf:close()
end

function src2cst(code)
   sw:measure()

   local cst_parser = require("yalf.parser.cst_parser")
   local a, new = cst_parser(code):parse()
   assert(a, new)

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
   local cst = file
   if type(file) == "string" then
      cst = file2cst(file)
   end

   sw:measure()

   local refs = refs or require("test_refactoring")
   visitor.visit(visitors.refactoring_visitor:new(refs), cst)

   sw:p("refactor")

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
            target = node:modify_index(self.target, Codegen.gen_expression_from_value({}))
         end

         node:modify_index(k, nil)

         target:primary_expression():modify_index(k, val)
      end
   end
end

function format_file(file)
   local cst = file2cst(file)

   sw:measure()

   local visitors = require("yalf.visitor.visitors")
   local spv = require("yalf.visitor.split_penalty_visitor")
   local rv = require("yalf.visitor.reformatting_visitor")
   visitor.visit(visitors.parenting_visitor:new(), cst)
   visitor.visit(spv:new(), cst)
   visitor.visit(rv:new(), cst)

   sw:p("format")

   return cst
end

-- =refactor_file("/home/ruin/build/elonafoobar/runtime/mod/core/data/chara.lua", { move_to_inner_table:new({"image"}, "_copy") })

local move_file = {}

local function is_require(node, path)
   return node:type() == "suffixed_expression"
      and node:is_function_call()
      and node:name() == "require"
      and node:arguments():count() > 0
      and node:arguments():at(1):raw_value() == path
end

function move_file:new(from, to)
   return setmetatable({from, to}, {__index = move_file})
end
function move_file:applies_to(node)
end
function move_file:execute(node)
end


effective_range = {
   [788] = {60, 90, 100, 100, 80, 60, 20, 20, 20, 20},
   [758] = {100, 90, 70, 50, 20, 20, 20, 20, 20, 20},
   [725] = {60, 100, 70, 20, 20, 20, 20, 20, 20, 20},
   [718] = {50, 100, 50, 20, 20, 20, 20, 20, 20, 20},
   [716] = {60, 100, 70, 20, 20, 20, 20, 20, 20, 20},
   [714] = {80, 100, 90, 80, 60, 20, 20, 20, 20, 20},
   [713] = {60, 100, 70, 20, 20, 20, 20, 20, 20, 20},
   [674] = {100, 40, 20, 20, 20, 20, 20, 20, 20, 20},
   [673] = {50, 90, 100, 90, 80, 80, 70, 60, 50, 20},
   [633] = {50, 100, 50, 20, 20, 20, 20, 20, 20, 20},
   [514] = {100, 100, 100, 100, 100, 100, 100, 50, 20, 20},
   [512] = {100, 100, 100, 100, 100, 100, 100, 20, 20, 20},
   [496] = {100, 60, 20, 20, 20, 20, 20, 20, 20, 20},
   [482] = {80, 100, 90, 80, 70, 60, 50, 20, 20, 20},
   [231] = {80, 100, 100, 90, 80, 70, 20, 20, 20, 20},
   [230] = {70, 100, 100, 80, 60, 20, 20, 20, 20, 20},
   [210] = {60, 100, 70, 20, 20, 20, 20, 20, 20, 20},
   [207] = {50, 90, 100, 90, 80, 80, 70, 60, 50, 20},
   [60] = {100, 90, 70, 50, 20, 20, 20, 20, 20, 20},
   [58] = {50, 90, 100, 90, 80, 80, 70, 60, 50, 20},
}

function effective_range:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index("elona_id")
   if not target or target:type() ~= "expression" or not target:to_value() then
      return false
   end

   return self[target:to_value()]
end
function effective_range:execute(node)
   local id = node:index("elona_id"):to_value()
   local tbl = self[id]
   local inspect = require("inspect")
   local expr = Codegen.gen_expression(inspect(tbl))
   node:modify_index("effective_range", expr)
end
