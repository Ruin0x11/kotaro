hotload = require("hotload")
hotload.hook_global_require()

kotaro = require("kotaro")
local stopwatch = require("stopwatch")
local visitor = require("kotaro.visitor")
local code_convert_visitor = require("kotaro.visitor.code_convert_visitor")
local rewriting_visitor = require("kotaro.visitor.rewriting_visitor")
local tree_utils = require("kotaro.parser.tree_utils")

local sw = stopwatch()

Codegen = require("kotaro.parser.codegen")
inspect = require("inspect")
-- cst = file2cst("test9.lua")

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

   local pv = require("kotaro.visitor.parenting_visitor")
   local spv = require("kotaro.visitor.split_penalty_visitor")
   local rv = require("kotaro.visitor.reformatting_visitor")
   visitor.visit(pv:new(), cst)
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


thing = {
    [788] = 15,
    [781] = 40,
    [759] = 100,
    [758] = 35,
    [741] = 20,
    [739] = 65,
    [735] = 5,
    [725] = 0,
    [718] = 5,
    [716] = 50,
    [714] = 0,
    [713] = 15,
    [678] = 10,
    [677] = 30,
    [675] = 15,
    [674] = 30,
    [673] = 20,
    [633] = 5,
    [514] = 5,
    [512] = 5,
    [496] = 30,
    [482] = 25,
    [359] = 40,
    [266] = 5,
    [235] = 30,
    [231] = 0,
    [230] = 15,
    [228] = 25,
    [225] = 10,
    [224] = 20,
    [213] = 25,
    [211] = 5,
    [210] = 5,
    [207] = 20,
    [206] = 20,
    [73] = 20,
    [64] = 15,
    [63] = 15,
    [60] = 10,
    [58] = 20,
    [57] = 25,
    [56] = 10,
    [2] = 10,
    [1] = 5,
}

add_field_by_legacy_id = {}

function add_field_by_legacy_id:new(field, items)
   return setmetatable({field = field, items = items}, {__index = add_field_by_legacy_id})
end
function add_field_by_legacy_id:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index("elona_id")
   if not target or target:type() ~= "expression" or not target:to_value() then
      return false
   end

   return self.items[target:to_value()] ~= nil
end
function add_field_by_legacy_id:execute(node)
   local id = node:index("elona_id"):to_value()
   local tbl = self.items[id]
   local inspect = require("inspect")
   local expr = Codegen.gen_expression(inspect(tbl))
   node:modify_index(self.field, expr)
end

modify_table_index = {}

function modify_table_index:new(field, cb)
   return setmetatable({field = field, cb = cb}, {__index = modify_table_index})
end
function modify_table_index:applies_to(node)
   if node:type() ~= "constructor_expression" then
      return false
   end

   local target = node:index(self.field)
   if not target or target:type() ~= "expression" or not target:to_value() then
      return false
   end

   return true
end
function modify_table_index:execute(node)
   local id = node:index(self.field):to_value()
   local val = self.cb(id)
   local expr = Codegen.gen_expression_from_value(val)
   node:modify_index(self.field, expr)
end

cst = kotaro.file_to_ast("test_refactoring.lua")

local function file2src(file)
   local input, err = io.open(file, "r")
   assert(input, err)

   local src = input:read("*all")
   input:close()

   return src
end

d = function()
   local a = file2src("test.lua")
   local b = file2src("test_diff.lua")

   local r = require("kotaro.replacements"):new()

   r:diff(a, b, "test.lua")
   r:write(io.stdout)
end
