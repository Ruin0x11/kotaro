local cst_unwrapper = require("kotaro.cst_unwrapper")
local kotaro = require("kotaro")
local fun = require("fun")

local function unwrap(src)
   local cst = assert(kotaro.source_to_ast(src))
   return cst_unwrapper.unwrap(cst)
end

local function dump(uwlines)
   local dump = function(uwline) return fun.iter(uwline:dump()):foldl(function(acc, x) return acc .. " " .. x end, "") end
   print(fun.iter(uwlines):map(dump):foldl(function(acc, x) return acc .. x .. "\n" end, ""))
end

function assert.first_tokens_eq(uwlines, tokens)
   assert.same(#tokens, #uwlines)
   for i, uwline in ipairs(uwlines) do
      if tokens[i] then
         assert.same(tokens[i], uwline.tokens[1].value)
      end
   end
end

function assert.depths_eq(uwlines, depths)
   assert.same(#depths, #uwlines)
   assert.same(depths, fun.iter(uwlines):map(function(l) return l.depth end):totable())
end

describe("cst_unwrapper",
         function()
            it("unwraps if blocks", function()
                  local uwlines = unwrap([[if true then
                                             x = 1
                                             y = 2
                                           end]])
                  assert.first_tokens_eq(uwlines, {"if", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps if blocks with else", function()
                  local uwlines = unwrap([[if true then
                                             x = 1
                                             y = 2
                                           elseif false then
                                             z = 1
                                           else
                                             w = 1
                                           end ]])
                  assert.first_tokens_eq(uwlines, {"if", "x", "y", "elseif", "z", "else", "w", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0, 1, 0, 1, 0})
            end)

            it("unwraps nested if blocks", function()
                  local uwlines = unwrap([[if true then
                                             if false then
                                                x = 1
                                              end
                                           end]])
                  assert.first_tokens_eq(uwlines, {"if", "if", "end"})
                  assert.depths_eq(uwlines, {0, 1, 0})
            end)

            it("does not unwrap simple if blocks", function()
                  local uwlines = unwrap("if true then x = 1 end")
                  assert.first_tokens_eq(uwlines, {"if"})
                  assert.depths_eq(uwlines, {0})
            end)

            it("does not unwrap simple if blocks with else", function()
                  local uwlines = unwrap([[if true then
                                             x = 1
                                           elseif false then
                                             y = 1
                                           else
                                             z = 1
                                           end]])
                  assert.first_tokens_eq(uwlines, {"if"})
                  assert.depths_eq(uwlines, {0})
            end)

            it("unwraps numeric for blocks", function()
                  local uwlines = unwrap([[for i = 1, 10, 2 do
                                             x = i
                                             y = i
                                           end]])
                  assert.first_tokens_eq(uwlines, {"for", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps generic for blocks", function()
                  local uwlines = unwrap([[for k, v in ipairs(it) do
                                             x = k
                                             y = v
                                           end]])
                  assert.first_tokens_eq(uwlines, {"for", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps function declarations", function()
                  local uwlines = unwrap([[local function test(param1, params2)
                                             x = k
                                             y = v
                                           end]])
                  assert.first_tokens_eq(uwlines, {"local", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps function declarations with return", function()
                  local uwlines = unwrap([[local function test(param1, params2)
                                             return 1
                                           end]])
                  assert.first_tokens_eq(uwlines, {"local"})
                  assert.depths_eq(uwlines, {0})
            end)

            it("unwraps function expressions", function()
                  local uwlines = unwrap([[local test = function(param1, params2)
                                             x = k
                                             y = v
                                           end]])
                  assert.first_tokens_eq(uwlines, {"local", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps repeat blocks", function()
                  local uwlines = unwrap([[repeat
                                             x = 1
                                             y = 2
                                           until true]])
                  assert.first_tokens_eq(uwlines, {"repeat", "x", "y", "until"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps do blocks", function()
                  local uwlines = unwrap([[do
                                             x = 1
                                             y = 2
                                           end]])
                  assert.first_tokens_eq(uwlines, {"do", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps while blocks", function()
                  local uwlines = unwrap([[while true do
                                             x = 1
                                             y = 2
                                           end]])
                  assert.first_tokens_eq(uwlines, {"while", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("does not unwrap simple do blocks", function()
                  local uwlines = unwrap("do x = 1 end")
                  assert.first_tokens_eq(uwlines, {"do"})
                  assert.depths_eq(uwlines, {0})
            end)

            it("unwraps blocks with semicolons", function()
                  local uwlines = unwrap([[do
                                             x = 1; y = 2
                                           end]])
                  assert.first_tokens_eq(uwlines, {"do", "x", "y", "end"})
                  assert.depths_eq(uwlines, {0, 1, 1, 0})
            end)

            it("unwraps dood", function()
                  local function read_to_string(file)
                     local f = assert(io.open(file, "rb"))
                     local content = f:read("*all")
                     f:close()
                     return content
                  end
                  local src = read_to_string("/home/ruin/build/elona-next/src/mod/elona/data/feat.lua")
                  local uwlines = unwrap(src)
                  dump(uwlines)
                  --assert.first_tokens_eq(uwlines, {"do", "x", "y", "end"})
            end)
end)
