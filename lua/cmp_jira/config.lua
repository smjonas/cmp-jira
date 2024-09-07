local M = {
    enabled = true,
    filetypes = { 'gitcommit' },
    jira = {
        url = '',
        email = '',
        jql = 'assignee=%s+and+resolution=unresolved',
    },
}

return M
