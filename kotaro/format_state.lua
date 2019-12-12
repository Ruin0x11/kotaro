local class = require("pl.class")
local tablex = require("pl.tablex")
local split_penalty = require("kotaro.split_penalty")
local utils = require("kotaro.utils")
local tree_utils = require("kotaro.parser.tree_utils")

local hash
if jit then
   hash = require("thirdparty.luaxxhash")
end

local format_state = class()

local function split(str, sep)
   local fields = {}
   local pattern = string.format("([^%s]+)", sep)
   string.gsub(str, pattern, function(c) fields[#fields+1] = c end)
   return fields
end

local paren_state = class()
function paren_state:_init(indent, last_space, name, block, must_indent_block)
   self.indent = indent
   self.last_space = last_space
   self.closing_scope_indent = 0
   self.split_before_closing_bracket = false
   self.num_line_splits = 0
   self.name = name
   self.block = block
   self.must_indent_block = must_indent_block
end

function paren_state:__eq(other)
   return self.indent == other.indent
      and self.last_space == other.last_space
      and self.closing_scope_indent == other.closing_scope_indent
      and self.split_before_closing_bracket == other.split_before_closing_bracket
      and self.num_line_splits == other.num_line_splits
      and self.must_indent_block == other.must_indent_block
end

function paren_state:clone()
   local new = paren_state(self.indent, self.last_space, self.name, self.block, self.must_indent_block)
   new.closing_scope_indent = self.closing_scope_indent
   new.split_before_closing_bracket = self.split_before_closing_bracket
   new.num_line_splits = self.num_line_splits
   return new
end

function paren_state:hash()
   return hash(string.format("%d%d%d%s%d%s",
                             self.indent,
                             self.last_space,
                             self.closing_scope_indent,
                             self.split_before_closing_bracket,
                             self.num_line_splits,
                             self.must_indent_block))
end

function paren_state:__tostring()
   return string.format("%s'%s' [paren:ind=%d,last=%s,close=%d,spl=%s,numsplits=%d,block=%s]",
                        string.rep(" ", self.indent + 2),
                        string.upper(self.name),
                        self.indent,
                        self.last_space,
                        self.closing_scope_indent,
                        self.split_before_closing_bracket,
                        self.num_line_splits,
                        self.must_indent_block and self.must_indent_block.value)
end

function format_state:_init(line, first_indent, config)
   self.line = line
   self.column = first_indent
   self.first_indent = first_indent
   self.next_token = line.tokens[1]
   self.lowest_level_on_line = 0
   self.paren_level = 0
   self.paren_stack = {paren_state(first_indent, first_indent, "root", nil, false)}
   self.newline = false
   self.config = config
   self.was_split = {}
end

function format_state:__eq(other)
   if not self.ignore_stack_for_comparison then
      if #self.paren_stack ~= #other.paren_stack then
         return false
      end
      for i, v in ipairs(self.paren_stack) do
         if v ~= other.paren_stack[i] then
            return false
         end
      end
   end

   return self.line == other.line
      and self.column == other.column
      and self.first_indent == other.first_indent
      and self.next_token == other.next_token
      and self.lowest_level_on_line == other.lowest_level_on_line
      and self.paren_level == other.paren_level
      and self.newline == other.newline
      and self.config == other.config
end

function format_state:clone()
   local new = format_state(self.line, self.first_indent, self.config)
   new.column = self.column
   new.next_token = self.next_token
   new.lowest_level_on_line = self.lowest_level_on_line
   new.paren_level = self.paren_level
   new.paren_stack = {}
   for i, v in ipairs(self.paren_stack) do
      new.paren_stack[i] = v:clone()
   end
   new.newline = self.newline
   new.was_split = {}
   for k, v in pairs(self.was_split) do
      new.was_split[k] = v
   end
   return new
end

function format_state:hash()
   local stack = 0
   for _, v in ipairs(self.paren_stack) do
      -- stack = stack + v:hash()
   end
   return hash(string.format("%d%s%d%d%d%s",
                             self.column,
                             self.next_token and self.next_token:hash() or "",
                             self.lowest_level_on_line,
                             self.paren_level,
                             stack,
                             self.newline))
end

function format_state:__tostring()
   local parens = ""
   for _, v in ipairs(self.paren_stack) do
      parens = parens .. "\n" .. tostring(v)
   end
   return string.format("[state:col=%d,next=%s,lowest=%d,paren=%d,nl=%s,parens=%s]",
                        self.column,
                        self.next_token and ("'%s'"):format(self.next_token.value),
                        self.lowest_level_on_line,
                        self.paren_level,
                        self.newline,
                        parens)
end

function format_state:check_between_tokens(start_tok, end_tok, cb)
   local tok = start_tok.next_token
   while tok and tok ~= end_tok do
      if cb(tok) then
         return true
      end
      tok = tok.next_token
   end

   return false
end

function format_state:calc_must_split()
   local current = self.next_token
   local prev = current.prev_token
   local cval = current.value
   local pval = prev.value
   local last = self.paren_stack[#self.paren_stack]

   if current.split_penalty >= split_penalty.unbreakable then
      return false
   end

   if prev.function_start then
      local function_end = prev.function_start.block_end
      assert(function_end)

      local start_indent = prev.function_start:spaces_before()
      if not self:fits_on_one_line(prev.function_start, function_end, start_indent) then
         return true
      end
   end

   -- Check if there is a break anywhere inside an if clause; if so,
   -- indent the following "then" keyword also.
   if current.if_clause_start
      and self:check_between_tokens(current.if_clause_start, current,
                                    function(n) return self.was_split[n] end)
   then
      return true
   end

   -- Always indent "then" and "else" unless the entire if block can
   -- fit onto one line.
   if prev.if_clause_start then
      local if_start = prev.if_start
      local if_end = if_start.block_end
      assert(if_end)

      local start_indent = if_start:spaces_before()
      if self:fits_on_one_line(if_start, if_end, start_indent) then
         return false
      end

      return true
   end

   if last.block and (current.value == "or" or current.value == "and") then
      local pred = function(n)
         return self.was_split[n] and (n.value == "or" or n.value == "and")
      end
      if self:check_between_tokens(last.block, current, pred)
      then
         return true
      end
   end

   if last.must_indent_block then
      if current.split_penalty >= split_penalty.unbreakable then
         return false
      end

      if cval == "(" and prev.leaf_type == "Ident" then
         return false
      end
      if pval == ":" or pval == "." then
         return false
      end

      if current.is_block_start and (current.block_start == last.block
                                        or current.matching_bracket == last.block)
      then
         return true
      end
      if prev.is_block_start and (prev.block_start == last.block
                                     or prev.matching_bracket == last.block)
      then
         return true
      end
      if current.is_block_end and (current.block_end == last.block.block_end
                                      or current.matching_bracket == last.block.block_end)
      then
         return true
      end

      if last.block.value == "}" and pval == "," then
         return true
      end
   end

   if pval == "{" then
      local closing = prev.matching_bracket
      assert(closing)
      assert(prev.is_block_start)
      if not self:fits_on_one_line(prev, closing) then
         last.split_before_closing_bracket = true
         return true
      end
   end

   if last.split_before_closing_bracket and cval == "}" then
      return last.split_penalty ~= split_penalty.unbreakable
   end

   return current.must_split or false
end

function format_state:calc_can_split()
   local current = self.next_token
   local prev = current.prev_token
   local cval = current.value
   local pval = prev.value
   local last = self.paren_stack[#self.paren_stack]

   if pval == "," then
      return true
   end

   if current.can_split == nil then
      return true
   end

   return current.can_split
end

function format_state:fits_on_one_line(first_tok, last_tok, column)
   column = column or self.column
   local length = last_tok.total_length - first_tok.total_length
   print("FITS",first_tok.value, first_tok.total_length, last_tok.value, last_tok.total_length, ("len %d + col %d = %d<%d"):format(length, self.column, length + self.column, self.config.column_limit))
   io.stdout:write("---------- ")
   while first_tok ~= nil do
      io.stdout:write(first_tok.value)
      io.stdout:write(string.rep(" ", first_tok.spaces_required_before))
      if first_tok == last_tok then
         break
      end
      first_tok = first_tok.next_token
   end
   io.stdout:write("\n")
   return length + column <= self.config.column_limit
end

function format_state:can_fit_block(block)
   assert(block.block_start)
   assert(block.block_end)
   return self:fits_on_one_line(block.block_start, block.block_end)
end

function format_state:add_token_on_current_line(dry_run)
   local current = self.next_token
   local prev = current.prev_token
   local last = self.paren_stack[#self.paren_stack]
   local spaces = current.spaces_required_before

   if not dry_run and current.leaf_type ~= "Eof" then
      current:add_prefix(0, spaces, nil, self.config)
   end

   if tree_utils.opens_scope(prev) then
      if current.leaf_type ~= "Comment" then
         -- foo = {a,
         --        b,
         --       }
         last.closing_scope_indent = self.column - 1
         if self.config.align_closing_bracket_with_visual_indent then
            last.closing_scope_indent = last.closing_scope_indent + 1
         end
         last.indent = self.column + spaces
      else
         last.closing_scope_indent = last.indent + self.config.continuation_indent_width
      end
   end

   self.column = self.column + spaces
end

local function is_compound_statement(token)
   return utils.set({"then", "do", "repeat", "else"})[token.value]
end

function format_state:calc_newline_column()
   local current = self.next_token
   local prev = current.prev_token
   local last = self.paren_stack[#self.paren_stack]

   if current.if_clause_start then
      return self.paren_stack[#self.paren_stack-1].indent
   end

   if current.spaces_required_before > 2 or self.line.disabled then
      return current.spaces_required_before
   end

   if tree_utils.opens_scope(current) then
      if self.paren_level > 0 then
         return last.indent
      else
         return self.first_indent
      end
   end

   if tree_utils.closes_scope(current) then
      if tree_utils.opens_scope(prev)
         or (prev.leaf_type == "Comment" and prev.prev_token and tree_utils.opens_scope(prev.prev_token))
      then
         return math.max(0, last.indent - self.config.continuation_indent_width)
      end
      return last.closing_scope_indent
   end

   if is_compound_statement(self.line.tokens[1])
      and (not self.config.dedent_closing_brackets
              or self.config.split_before_first_argument)
   then
      local token_indent = self.line.tokens[1]:spaces_before() + self.config.indent_width
      if token_indent == last.indent then
         return last.indent + self.config.continuation_indent_width
      end
   end

   -- assignment
   if prev.value == "=" then
      return last.indent + self.config.continuation_indent_width
   end

   if current.value == ":" then
      if self.config.align_method_chains then
         return last.indent + string.len(current.first_suffix.value)
      else
         return last.indent + self.config.continuation_indent_width
      end
   end

   return last.indent
end

function format_state:add_token_on_newline(dry_run, must_split)
   local current = self.next_token
   local prev = current.prev_token
   local last = self.paren_stack[#self.paren_stack]

   self.column = self:calc_newline_column()

   self.was_split[current] = true

   if not dry_run then
      local indent_level = self.line.depth
      local spaces = self.column
      if spaces > 0 then
         spaces = spaces - indent_level * self.config.indent_width
      end
      current:add_prefix(1, spaces, indent_level, self.config)

      local tok = current
      local len = self.column
      while tok do
         len = len + string.len(tok.value) + tok.spaces_required_before
         tok.total_length = len
         tok = tok.next_token
      end
   end

   if current.leaf_type ~= "Comment" then
      last.last_space = self.column
   end
   self.lowest_level_on_line = self.paren_level

   if tree_utils.opens_scope(prev)
      or prev.function_start
      or (prev.leaf_type == "Comment"
             and prev.prev_token
             and tree_utils.opens_scope(prev.prev_token))
   then
      last.closing_scope_indent = math.max(0, last.indent - self.config.continuation_indent_width)
   end

   last.split_before_closing_bracket = true

   local penalty = current.split_penalty

   if must_split then
      return penalty
   end

   if not utils.set({"do", "then", "repeat", "else"})[current.value] then
      last.num_line_splits = last.num_line_splits + 1
      penalty = penalty + self.config.split_penalty_for_added_line_split * last.num_line_splits
   end

   if tree_utils.opens_scope(current) and tree_utils.opens_scope(prev) then
      local prev_token = prev.prev_token
      if not prev_token or not prev_token.leaf_type == "Ident" then
         penalty = penalty + 10
      end
   end

   -- Add a penalty if this is an expression where a previous boolean
   -- test wasn't split. Prefer all boolean statements to be split if
   -- any one of them is split.
   if last.block then
      local pred = function(n)
         return not self.was_split[n] and (n.value == "or" or n.value == "and")
      end
      if self:check_between_tokens(last.block, current, pred)
      then
         penalty = penalty + 10000
      end
   end

   return penalty + 10
end

function format_state:add_token_to_state(do_newline, dry_run, must_split)
   local penalty = 0
   if do_newline then
      penalty = self:add_token_on_newline(dry_run, must_split)
   else
      self:add_token_on_current_line(dry_run)
   end

   return self:move_to_next_token() + penalty
end

function format_state:move_to_next_token()
   local current = self.next_token

   if not tree_utils.opens_scope(current) and not tree_utils.closes_scope(current) then
      self.lowest_level_on_line = math.min(self.lowest_level_on_line, self.paren_level)
   end

   if #self.paren_stack > 1 and tree_utils.closes_scope(current) then
      -- print("CLOSE", string.rep("<", self.paren_level) .. " " .. current.value, current.prev_token and current.prev_token.value, current.line, current.column)
      -- print(self)

      local last = self.paren_stack[#self.paren_stack]
      local sec_last = self.paren_stack[#self.paren_stack-1]
      sec_last.last_space = last.last_space

      self.paren_stack[#self.paren_stack] = nil
      self.paren_level = self.paren_level - 1
   end

   if tree_utils.opens_scope(current) or current.is_block_start then
      -- print("OPEN", string.rep(">", self.paren_level) .. " " .. current.value, current.prev_token and current.prev_token.value, current.line, current.column)
      -- print(self)
      local last = self.paren_stack[#self.paren_stack]
      local new_indent = self.config.continuation_indent_width + last.last_space

      local must_indent_block = false
      local block
      if current.matching_bracket then
         block = current.matching_bracket
         if not self:fits_on_one_line(current, current.matching_bracket) then
            must_indent_block = true
         end
      elseif current.block_start then
         block = current.block_start
         if not self:can_fit_block(current.block_start, self.config) then
            must_indent_block = true
         end
      end

      self.paren_stack[#self.paren_stack+1] = paren_state(new_indent, last.last_space, current.value, block, must_indent_block)
      self.paren_level = self.paren_level + 1
   end

   local is_multiline_string = current.leaf_type == "string" and string.find(current.value, "\n")
   if is_multiline_string then
      self.column = self.column + string.len(split(current.value, "\n")[1])
   else
      self.column = self.column + string.len(current.value)
   end

   self.next_token = self.next_token.next_token

   local penalty = 0
   if self.column > self.config.column_limit then
      local excess_characters = self.column - self.config.column_limit
      penalty = penalty + self.config.split_penalty_excess_character * excess_characters
   end

   if is_multiline_string then
      local spl = split(current.value, "\n")
      self.column = self.column + string.len(spl[#spl])
   end

   return penalty
end

return format_state
