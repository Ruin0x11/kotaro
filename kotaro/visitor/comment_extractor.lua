-- visitor for extracting comments in node prefixes to full CST nodes.
--
-- for the purposes of source code analysis, putting comments in the
-- prefixes significantly reduces complexity. however, when formatting
-- it is far more useful to have them as individual elements.
--
-- note that after this pass is complete, it is an error to use the
-- metatable methods of CST nodes since comments will be spliced into
-- each node table, breaking the assumptions each method makes about
-- the position of CST elements.
local comment_extractor = {}

return comment_extractor
