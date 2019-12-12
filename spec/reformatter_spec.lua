local reformatter = require("kotaro.reformatter")
local cst_unwrapper = require("kotaro.cst_unwrapper")
local visitor = require("kotaro.visitor")
local identify_containers_visitor = require("kotaro.visitor.identify_containers_visitor")
local split_penalty_visitor = require("kotaro.visitor.split_penalty_visitor")
local kotaro = require("kotaro")
local utils = require("kotaro.utils")
local ansicolors = require("ansicolors")

local CONFIG = {
   indent_width = 3,
   column_limit = 40,
   continuation_indent_width = 2,
   split_penalty_excess_character = 7000,
   split_penalty_for_added_line_split = 30,
   split_penalty_after_opening_bracket = 10,
   split_penalty_logical_operator = 300,
   split_penalty_bitwise_operator = 300,
   split_penalty_after_unary_operator = 10000,
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
      assert.same_string(target, reformat(source))
   end
end

function assert.same_string(str1, str2)
   local lines = "\n"
   local spl1 = utils.split_string(str1, "\n")
   local spl2 = utils.split_string(str2, "\n")
   local len = math.max(#spl1, #spl2)
   local failed = false
   local buf = {}

   local function print_buf()
      for _, l in ipairs(buf) do
         lines = lines .. string.format(ansicolors("%{red}- %s%{reset}\n"), l)
      end
      buf = {}
   end

   for i = 1, len do
      local a = spl1[i]
      local b = spl2[i]

      if a ~= b then
         failed = true
         if a ~= nil then
            lines = lines .. string.format(ansicolors("%{green}+ %s%{reset}\n"), a)
            if b ~= nil then
               buf[#buf+1] = b
            end
         else
            print_buf()
            if b ~= nil then
               lines = lines .. string.format(ansicolors("%{red}- %s%{reset}\n"), b)
            end
         end
      else
         print_buf()
         lines = lines .. string.format("  %s\n", b)
      end
   end

   print_buf()

   if failed then
      print(str1, str2)
      error("Expected output differs:".. lines)
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
                  local conf = utils.deepcopy(CONFIG)
                  conf.column_limit = 80
                  print(reformat(read_to_string("/home/ruin/build/elona-next/src/api/chara/IChara.lua"), conf))
            end)
end)
