local class = require("pl.class")
local utils = require("kotaro.utils")
local NodeTypes = require("kotaro.parser.node_types")

local WhiteChars = utils.set{' ', '\n', '\t', '\r'}
local EscapeLookup = {['\r'] = '\\r', ['\n'] = '\\n', ['\t'] = '\\t', ['"'] = '\\"', ["'"] = "\\'"}
local LowerChars = utils.set{'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i',
                       'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r',
                       's', 't', 'u', 'v', 'w', 'x', 'y', 'z'}
local UpperChars = utils.set{'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I',
                       'J', 'K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R',
                       'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z'}
local Digits = utils.set{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9'}
local HexDigits = utils.set{'0', '1', '2', '3', '4', '5', '6', '7', '8', '9',
                      'A', 'a', 'B', 'b', 'C', 'c', 'D', 'd', 'E', 'e', 'F', 'f'}

local Symbols = utils.set{'+', '-', '*', '/', '^', '%', ',', '{', '}', '[', ']', '(', ')', ';', '#'}

local Keywords = utils.set{
   'and', 'break', 'do', 'else', 'elseif',
   'end', 'for', 'function', 'goto', 'if',
   'in', 'local', 'not', 'or', 'repeat',
   'return', 'then', 'until', 'while',
};

local Booleans = utils.set{'true', 'false'}

local lexer = class()

function lexer:_init(src, filename)
   self.p = 1
   self.line = 1
   self.char = 1
   self.src = src
   self.next = {}
   self.filename = filename or "<string>"
end

function lexer:get()
   local c = self.src:sub(self.p,self.p)
   if c == '\n' then
      self.char = 1
      self.line = self.line + 1
   else
      self.char = self.char + 1
   end
   self.p = self.p + 1
   return c
end

function lexer:peek(n)
   n = n or 0
   return self.src:sub(self.p+n,self.p+n)
end

function lexer:consume(chars)
   local c = self:peek()
   for i = 1, #chars do
      if c == chars:sub(i,i) then return self:get() end
   end
end

function lexer:generateError(err)
   return error(string.format("%s:%s:%s: %s", self.filename, self.line, self.char, err), 0)
end

function lexer:tryGetLongString()
   local start = self.p
   if self:peek() == '[' then
      local equalsCount = 0
      local depth = 1
      while self:peek(equalsCount+1) == '=' do
         equalsCount = equalsCount + 1
      end
      if self:peek(equalsCount+1) == '[' then
         --start parsing the string. Strip the starting bit
         for _ = 0, equalsCount+1 do self:get() end

         --get the contents
         local contentStart = self.p
         while true do
            --check for eof
            if self:peek() == '' then
               self:generateError("Expected `]"..string.rep('=', equalsCount).."]` near <eof>.", 3)
            end

            --check for the end
            local foundEnd = true
            if self:peek() == ']' then
               for i = 1, equalsCount do
                  if self:peek(i) ~= '=' then foundEnd = false end
               end
               if self:peek(equalsCount+1) ~= ']' then
                  foundEnd = false
               end
            else
               if self:peek() == '[' then
                  -- is there an embedded long string?
                  local embedded = true
                  for i = 1, equalsCount do
                     if self:peek(i) ~= '=' then
                        embedded = false
                        break
                     end
                  end
                  if self:peek(equalsCount + 1) == '[' and embedded then
                     -- oh look, there was
                     depth = depth + 1
                     for i = 1, (equalsCount + 2) do
                        self:get()
                     end
                  end
               end
               foundEnd = false
            end
            --
            if foundEnd then
               depth = depth - 1
               if depth == 0 then
                  break
               else
                  for i = 1, equalsCount + 2 do
                     self:get()
                  end
               end
            else
               self:get()
            end
         end

         --get the interior string
         local contentString = self.src:sub(contentStart, self.p-1)

         --found the end. Get rid of the trailing bit
         for i = 0, equalsCount+1 do self:get() end

         --get the exterior string
         local longString = self.src:sub(start, self.p-1)

         --return the stuff
         return contentString, longString
      else
         return nil
      end
   else
      return nil
   end
end

function lexer:emit()
   --get leading whitespace. The leading whitespace will include any comments
   --preceding the token. This prevents the parser needing to deal with comments
   --separately.
   local leading = ""
   local leadingWhite = ''
   local longStr = false
   while true do
      local c = self:peek()
      if c == '#' and self:peek(1) == '!' and self.line == 1 then
         -- #! shebang for linux scripts
         self:get()
         self:get()
         leadingWhite = "#!"
         while self:peek() ~= '\n' and self:peek() ~= '' do
            leadingWhite = leadingWhite .. self:get()
         end
         local token = {
            Type = 'Comment',
            CommentType = 'Shebang',
            Data = leadingWhite,
            Line = self.line,
            Char = self.char
         }
         leadingWhite = ""
         leading = leading .. leadingWhite
      end
      if c == ' ' or c == '\t' then
         --whitespace
         --leadingWhite = leadingWhite..get()
         local c2 = self:get() -- ignore whitespace
         leading = leading .. c2
      elseif c == '\n' or c == '\r' then
         local nl = self:get()
         if leadingWhite ~= "" then
            local token = {
               Type = 'Comment',
               CommentType = longStr and 'LongComment' or 'Comment',
               Data = leadingWhite,
               Line = self.line,
               Char = self.char,
            }
            leading = leading .. leadingWhite
            leadingWhite = ""
         end
         leading = leading .. nl
      elseif c == '-' and self:peek(1) == '-' then
         --comment
         self:get()
         self:get()
         leadingWhite = leadingWhite .. '--'
         local _, wholeText = self:tryGetLongString()
         if wholeText then
            leadingWhite = leadingWhite..wholeText
            longStr = true
         else
            while self:peek() ~= '\n' and self:peek() ~= '' do
               leadingWhite = leadingWhite..self:get()
            end
         end
      else
         break
      end
   end
   if leadingWhite ~= "" then
      local token = {
         Type = 'Comment',
         CommentType = longStr and 'LongComment' or 'Comment',
         Data = leadingWhite,
         Line = self.line,
         Char = self.char,
      }
      leading = leading .. leadingWhite
   end

   --get the initial char
   local thisLine = self.line
   local thisChar = self.char
   local thisOffset = self.p
   local c = self:peek()

   --symbol to emit
   local toEmit = NodeTypes.leaf()

   --branch on type
   if c == '' then
      --eof
      toEmit.leaf_type = "Eof"
      toEmit.value = ""
   elseif UpperChars[c] or LowerChars[c] or c == '_' then
      --ident or keyword
      local start = self.p
      repeat
         self:get()
         c = self:peek()
      until not (UpperChars[c] or LowerChars[c] or Digits[c] or c == '_')
      local dat = self.src:sub(start, self.p-1)
      if Keywords[dat] then
         toEmit.leaf_type = "Keyword"
      elseif Booleans[dat] then
         toEmit.leaf_type = "Boolean"
      elseif dat == "nil" then
         toEmit.leaf_type = "Nil"
      else
         toEmit.leaf_type = "Ident"
      end
      toEmit.value = dat

   elseif Digits[c] or (self:peek() == '.' and Digits[self:peek(1)]) then
      --number const
      local start = self.p
      if c == '0' and self:peek(1) == 'x' then
         self:get()
         self:get()
         while HexDigits[self:peek()] do self:get() end
         if self:consume('Pp') then
            self:consume('+-')
            while Digits[self:peek()] do self:get() end
         end
      else
         while Digits[self:peek()] do self:get() end
         if self:consume('.') then
            while Digits[self:peek()] do self:get() end
         end
         if self:consume('Ee') then
            self:consume('+-')
            while Digits[self:peek()] do self:get() end
         end
      end
      toEmit.leaf_type = "Number"
      toEmit.value = self.src:sub(start, self.p-1)

   elseif c == '\'' or c == '\"' then
      local start = self.p
      --string const
      local delim = self:get()
      while true do
         local ch = self:get()
         if ch == '\\' then
            self:get() --get the escape char
         elseif ch == delim then
            break
         elseif ch == '' then
            self:generateError("Unfinished string near <eof>")
         end
      end
      local constant = self.src:sub(start, self.p-1)
      toEmit.leaf_type = "String"
      toEmit.value = constant

   elseif c == '[' then
      local _, wholetext = self:tryGetLongString()
      if wholetext then
         toEmit.leaf_type = "String"
         toEmit.value = wholetext
         -- toEmit = {Type = 'String', Data = wholetext, Constant = content}
      else
         self:get()
         toEmit.leaf_type = "Symbol"
         toEmit.value = "["
      end

   elseif self:consume('>=<') then
      toEmit.leaf_type = "Symbol"
      if self:consume('=') then
         toEmit.value = c.."="
      else
         toEmit.value = c
      end

   elseif self:consume('~') then
      if self:consume('=') then
         toEmit.leaf_type = "Symbol"
         toEmit.value = "~="
      else
         self:generateError("Unexpected symbol `~` in source.", 2)
      end

   elseif self:consume('.') then
      toEmit.leaf_type = "Symbol"
      if self:consume('.') then
         if self:consume('.') then
            toEmit.value = "..."
         else
            toEmit.value = ".."
         end
      else
         toEmit.value = "."
      end

   elseif self:consume(':') then
      toEmit.leaf_type = "Symbol"
      if self:consume(':') then
         toEmit.value = "::"
      else
         toEmit.value = ":"
      end

   elseif Symbols[c] then
      self:get()
      toEmit.leaf_type = "Symbol"
      toEmit.value = c

   else
      local contents, all = self:tryGetLongString()
      if contents then
         toEmit.leaf_type = "String"
         toEmit.value = all
         -- toEmit = {Type = 'String', Data = all, Constant = contents}
      else
         self:generateError("Unexpected Symbol `"..c.."` in source.", 2)
      end
   end

   --add the emitted symbol, after adding some common data
   toEmit._prefix = leading -- table of leading whitespace/comments
   --for k, tok in pairs(leading) do
   --	tokens[#tokens + 1] = tok
   --end

   toEmit.line = thisLine
   toEmit.column = thisChar
   toEmit.offset = thisOffset

   return toEmit
end

function lexer:consumeToken()
   if #self.next == 0 then
      return self:emit()
   end

   return table.remove(self.next, 1)
end

function lexer:peekToken(i)
   i = i or 1
   if not self.next then
      self:consumeToken()
   end
   while not self.next[i] do
      table.insert(self.next, self:emit())
   end
   return self.next[i]
end

function lexer:tokenIs(_type)
   return self:peekToken().leaf_type == _type
end

function lexer:tokenIsKeyword(kw)
   local t = self:peekToken()
   return t.leaf_type == "Keyword" and t.value == kw
end

function lexer:tokenIsSymbol(sym)
   local t = self:peekToken()
   return t.leaf_type == "Symbol" and t.value == sym
end

function lexer:consumeSymbol(sym)
   local t = self:peekToken()
   if t.leaf_type == "Symbol" and t.value == sym then
      self:consumeToken()
      return t
   end
   return nil
end

function lexer:consumeKeyword(kw)
   local t = self:peekToken()
   if t.leaf_type == "Keyword" and t.value == kw then
      self:consumeToken()
      return t
   end
   return nil
end

function lexer:isEof()
   return self:tokenIs("Eof")
end

return lexer
