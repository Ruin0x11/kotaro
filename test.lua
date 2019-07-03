local nodes, asd = require("yalf.parser.nodes")
local node = nodes.node
local leaf = nodes.leaf
local lexer = require("pl.lexer")

local sw = require("stopwatch")()

local a = node("test", {leaf("asd", "dood"),leaf("zxc", "zxc")})
local b = node("test", {leaf("asd", "dood"),leaf("zxc", "zxc")})

-- print(a == b)


local visitors = require("yalf.visitor.visitors")
local print_visitor = visitors.print_visitor
local visitor = visitors.visitor

-- print_visitor():visit(a)

local inf = io.open(arg[1], 'r')
if not inf then --comment
   print("Failed to open `"..arg[1].."` for reading")
   return
end
--
local sourceText = inf:read('*all')
inf:close()

local l = require("yalf.parser.lexer")(sourceText)
local i = require("inspect")

sw:measure()
local cst_parser = require("yalf.parser.cst_parser")
local a, new = cst_parser(sourceText):parse()
sw:p("parse")
if not a then
   print(new)
end

local f1 = io.open("/tmp/f1", "w")
local f2 = io.open("/tmp/f2", "w")
f1:write(sourceText)
f2:write(tostring(new))
f1:close()
f2:close()

if new ~= sourceText then
   os.execute("diff /tmp/f1 /tmp/f2 --color=always")
end


local change_execute = {}

local function get_function(call_stmt)
   local s = ""
   local dood = call_stmt.children[1]
   for i=1,#dood.children-1 do
      s = s .. dood.children[i]:get_value()
   end
   print(s)
   return s
end

local function dump(node)
   visitor.visit(print_visitor:new(), node)
end

local ast_maker = require("yalf.parser.ast_maker")
local ast = ast_maker:new()

local result = ast:visit(new)
sw:p("astmake")

local class = require("thirdparty.pl.class")

-- visitor.visit(visitors.ast_print_visitor:new(), result)
-- print(result)

local ex = {}

function ex:applies_to(node)
   if node.type ~= "FunctionDeclaration" then
      return false
   end

   print(node:get_declarer())
   print(node:get_full_name())
   print(node:get_args():get_nth(1))
   return node:get_declarer() == "_M"
end

function ex:execute(node)
   node:set_declarer("Asdfg")
end

local ex2 = {}

function ex2:applies_to(node)
end

function ex2:execute(node)
end

local rf = visitors.refactoring_visitor:new({ex})

visitor.visit(rf, result)

--print(tostring(result))
