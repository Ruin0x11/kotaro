local class = require("pl.class")
local fun = require("fun")
local split_penalty = require("kotaro.split_penalty")
local utils = require("kotaro.utils")
local tree_utils = require("kotaro.parser.tree_utils")

local unwrapped_line = class()

function unwrapped_line:_init(depth, tokens)
   self.tokens = tokens or {}
   self.depth = depth
end

function unwrapped_line:__eq(other)
   if #self.tokens ~= #other.tokens then
      return false
   end
   for i, v in ipairs(self.tokens) do
      if v ~= other.tokens[i] then
         return false
      end
   end

   return self.depth == other.depth
end

function unwrapped_line:__tostring()
   local s = ""
   for _, v in ipairs(self.tokens) do
      s = s .. v:as_code()
   end
   s = s:gsub("^\n*", "")
   return string.format("[line:depth=%d:%s]", self.depth, s)
end

function unwrapped_line:append_node(node)
   self.tokens = self.tokens or {}
   self.tokens[#self.tokens+1] = node
end

function unwrapped_line:dump()
   return fun.iter(self.tokens or {}):map(function(l) return l.value end):totable()
end

local EXPRS = utils.set({ "Keyword", "Boolean", "Ident", "String", "Number", "Nil" })

local function is_expr_start(token)
   if tree_utils.opens_scope(token) then
      return true
   end
   return EXPRS[token.leaf_type]
end

local function is_expr_end(token)
   if tree_utils.closes_scope(token) then
      return true
   end
   return EXPRS[token.leaf_type]
end

local BLOCK_START_KWS = utils.set({"do", "repeat", "then", "else", "end", "until", "return"})

local function is_space_required_between(left, right, config)
   local lval = left.value
   local rval = right.value

   -- tbl:method()
   if lval == ":" or rval == ":" then
      return false
   end

   -- not -3 < x
   if left.value == "not" and right.is_unary_op then
      return true
   end

   if left.is_unary_op and lval ~= "not" then
      return false
   end

   -- fn(-1)
   if tree_utils.opens_scope(left) and right.is_unary_op then
      return false
   end

   if left.is_binary_op or right.is_binary_op then
      return true
   end

   if EXPRS[left.leaf_type] and rval == "(" then
      return false
   end
   if EXPRS[left.leaf_type] and rval == "[" then
      return false
   end
   if lval == "then" or lval == "else" or lval == "do" then
      return true
   end
   if BLOCK_START_KWS[rval] then
      return true
   end
   if lval == "function" and rval == "(" then
      return false
   end
   if lval == ")" and is_expr_start(right) then
      return true
   end

   -- tbl.field
   if lval == "." or rval == "." then
      return false
   end

   -- { 1, 2, 3 }
   if config.space_around_tables then
      if lval == "{" or rval == "}" then
         return true
      end
   end

   -- {1, 2, }
   if lval == "," and tree_utils.closes_scope(right) then
      return not not config.space_between_ending_comma_and_closing_bracket
   end

   if (lval == "(" and rval == ")")
      or (lval == "[" and rval == "]")
      or (lval == "{" and rval == "}")
   then
      return false
   end

   -- fn(1, true, "str")
   if tree_utils.opens_scope(left) and is_expr_start(right) then
      return false
   end
   if tree_utils.closes_scope(right) then
      return false
   end
   if is_expr_end(left) and rval == "," then
      return false
   end

   if lval == "..." or rval == "..." then
      return false
   end

   if rval == ";" then
      return false
   end

   if right.leaf_type == "Eof" then
      return false
   end

   return true
end

local LOGICAL_OPS = utils.set { "and", "or" }
local BITWISE_OPS = utils.set { "|", "^", "&" }
local OPEN_PARENS = utils.set { "(", "{", "["}
local CLOSE_PARENS = utils.set { ")", "}", "]"}

local function calc_split_penalty(prev_token, cur_token, config)
   local pval = prev_token.value
   local cval = cur_token.value

   if pval == "not" then
      return split_penalty.unbreakable
   end

   if cur_token.split_penalty and cur_token.split_penalty > 0 then
      return cur_token.split_penalty
   end

   if BLOCK_START_KWS[cval] then
      return 0
   end

   if BLOCK_START_KWS[pval] then
      return 100
   end

   if config.split_before_logical_operator then
      if LOGICAL_OPS[pval] then
         return config.split_penalty_logical_operator
      elseif LOGICAL_OPS[cval] then
         return 0
      end
   else
      if LOGICAL_OPS[cval] then
         return 0
      elseif LOGICAL_OPS[cval] then
         return config.split_penalty_logical_operator
      end
   end

   if config.split_before_bitwise_operator then
      if BITWISE_OPS[pval] then
         return config.split_penalty_bitwise_operator
      elseif BITWISE_OPS[cval] then
         return 0
      end
   else
      if BITWISE_OPS[cval] then
         return 0
      elseif BITWISE_OPS[cval] then
         return config.split_penalty_bitwise_operator
      end
   end

   if prev_token.is_unary_op then
      return config.split_penalty_after_unary_operator
   end

   if pval == "," then
      return 0
   end

   if cval == "=" then
      return split_penalty.unbreakable
   end

   if cval == "==" then
      return split_penalty.strongly_connected
   end

   if OPEN_PARENS[pval] and cval ~= "(" then
      return config.split_penalty_after_opening_bracket
   end

   if CLOSE_PARENS[cval] then
      return 100
   end

   return 0
end

local function is_surrounded_by_brackets(token)
end

local function calc_must_split(prev_token, cur_token)
   if prev_token.leaf_type == "Comment" then
      return true
   end
   if cur_token.leaf_type == "String"
      and prev_token.leaf_type == "String"
      and is_surrounded_by_brackets(cur_token)
   then
      return true
   end

   return cur_token.must_split
end

local NO_BREAK_SYMS = utils.set { "(", "[", "," }

local function calc_can_split(prev_token, cur_token, config)
   local pval = prev_token.value
   local cval = cur_token.value

   if cur_token.split_penalty >= split_penalty.unbreakable then
      return false
   end

   if pval == ":" then
      return false
   end

   if pval == "#" then
      return false
   end

   if is_expr_end(prev_token) and NO_BREAK_SYMS[cval] then
      return false
   end

   -- don't split on empty tables
   if tree_utils.opens_scope(prev_token) and tree_utils.closes_scope(cur_token) then
      return false
   end

   if config.break_after_dot then
      if cval == "." then
         return false
      end
   else
      if pval == "." then
         return false
      end
   end

   if cur_token.leaf_type == "Comment" and prev_token.line == cur_token.line then
      return false
   end

   if prev_token.is_unary_op then
      return false
   end

   return true
end

function unwrapped_line:calc_formatting_info(config)
   local first = self.tokens[1]
   if first == nil then
      return
   end

   first.total_length = string.len(first.value)
   first.spaces_required_before = config.indent_width * self.depth

   local prev_token = first
   local prev_length = first.total_length
   for i = 2, #self.tokens do
      local token = self.tokens[i]
      token.spaces_required_before = 0
      if is_space_required_between(prev_token, token, config) then
         token.spaces_required_before = 1
      end

      local len = string.len(token.value)
      token.total_length = prev_length + len + token.spaces_required_before

      token.split_penalty = (token.split_penalty or 0) + calc_split_penalty(prev_token, token, config)
      token.must_split = calc_must_split(prev_token, token)
      token.can_split = token.must_split or calc_can_split(prev_token, token, config)
      -- print(string.format("'%s':%d\t'%s':%d", prev_token.value, prev_token.split_penalty, token.value, token.split_penalty))

      prev_token.next_token = token
      token.prev_token = prev_token

      prev_length = token.total_length
      prev_token = token
   end
end

return unwrapped_line
