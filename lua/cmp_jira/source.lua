local cmp = require("cmp")
local curl = require "plenary.curl"
local utils = require("cmp_jira.utils")

local source = {
  config = {},
  filetypes = {},
  cache = {}
}

source.new = function(overrides)
  local self =
      setmetatable(
        {},
        {
          __index = source
        }
      )

  self.config = vim.tbl_extend("force", require("cmp_jira.config"), overrides or {})
  for _, item in ipairs(self.config.filetypes) do
    self.filetypes[item] = true
  end
  self.enabled = self.config.enabled

  -- defaults
  if self.config.jira.jql == nil or self.config.jira.jql == "" then
    self.config.jira.jql = "(assignee = currentUser() OR reporter = currentUser()) order by updated DESC"
  end

  return self
end

function source:is_available()
  if self.filetypes["*"] == nil and self.filetypes[vim.bo.filetype] == nil then
    return false
  end
  return self.enabled == true or self.enabled()
end

function source:complete(_, callback)
  -- try to get the items from cache first before calling the API
  local bufnr = vim.api.nvim_get_current_buf()
  if self.cache[bufnr] then
    callback({ items = self.cache[bufnr] })
    return true
  end

  local req_url = utils.get_request_url(self.config)
  local auth = utils.get_basic_auth(self.config)
  if not auth then
    return false
  end

  -- run curl command
  curl.get(
    req_url,
    {
      auth = auth,
      callback = function(out)
        local ok, parsed_issues = utils.parse_api_response(out.body)
        if not ok then
          return false
        end

        local items = {}
        for _, issue in ipairs(parsed_issues) do
          local label = string.format("%s: %s", issue.key, issue.summary)
          table.insert(
            items,
            {
              label = label,
              filterText = label,
              insertText = label,
              sortText = issue.key,
              description = issue.description,
            }
          )
        end

        -- update the cache
        self.cache[bufnr] = items

        callback({ items = items })
        return true
      end
    }
  )

  return false
end

function source:resolve(completion_item, callback)
  local desc = completion_item.description
  if desc ~= vim.NIL then
    desc = desc:gsub("{{", "`"):gsub("}}", "`")
  end
  completion_item.documentation = {
    kind = cmp.lsp.MarkupKind.Markdown,
    value = desc,
  }
  callback(completion_item)
end

function source:get_debug_name()
  return "cmp_jira"
end

return source
