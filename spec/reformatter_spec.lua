local reformatter = require("kotaro.reformatter")
local cst_unwrapper = require("kotaro.cst_unwrapper")
local visitor = require("kotaro.visitor")
local identify_containers_visitor = require("kotaro.visitor.identify_containers_visitor")
local split_penalty_visitor = require("kotaro.visitor.split_penalty_visitor")
local kotaro = require("kotaro")

local CONFIG = {
   indent_width = 3,
   column_limit = 40,
   continuation_indent_width = 2,
   split_penalty_excess_character = 2,
   split_penalty_for_added_line_split = 2,
   split_penalty_after_opening_bracket = 10,
   split_penalty_logical_operator = 10,
   split_penalty_bitwise_operator = 10,
   split_penalty_after_unary_operator = 1000,
}

local function read_to_string(file)
   local f = assert(io.open(file, "rb"))
   local content = f:read("*all")
   f:close()
   return content
end

local function reformat(src, config)
   config = config or CONFIG
   local cst = assert(kotaro.source_to_ast(src))
   visitor.visit(identify_containers_visitor:new(), cst)
   visitor.visit(split_penalty_visitor:new(), cst)
   local uwlines = cst_unwrapper.unwrap(cst)
   return reformatter.reformat(uwlines, nil, config)
end

local function make_test(path)
   local raw = read_to_string(path)
   local pos = string.find(raw, "-- Result --")
   local source = string.sub(raw, 0, pos-1)
   local target = string.sub(raw, pos+13)
   assert(source and target)

   return function()
      assert.same(target, reformat(source))
   end
end

describe("formatter", function()
            local dir = "spec/test_fixtures/formatter"
            for path in lfs.dir(dir) do
               if path ~= "." and path ~= ".." then
                  it(("parses %s"):format(path), make_test(dir .. "/" .. path))
               end
            end

            it("parses dood", function()
                  print(reformat(read_to_string("/home/ruin/build/elona-next/src/api/Rand.lua")))
            end)
end)
