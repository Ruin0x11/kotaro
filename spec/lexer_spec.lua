local lexer = require("kotaro.parser.lexer")

local function lex(src)
   return lexer(src, "test")
end

describe("lexer",
         function()
            it("lexes prefix", function()
                  local l = lex("\nx = 1")
                  local t = l:peekToken()
                  assert.same("\n", t:prefix())
            end)

            it("lexes comment prefix", function()
                  local l = lex("--test comment\n--\nx = 1")
                  local t = l:peekToken()
                  assert.same("--test comment\n--\n", t:prefix())
            end)
end)
