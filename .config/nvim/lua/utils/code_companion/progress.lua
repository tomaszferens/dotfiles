local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
local group = vim.api.nvim_create_augroup("CodeCompanionFidgetHooks", { clear = true })
vim.api.nvim_create_autocmd({ "User" }, {
  pattern = "CodeCompanion*",
  group = group,
  callback = function(request)
    -- Only handle RequestStarted and RequestFinished events
    if not (vim.endswith(request.match, "RequestStarted") or vim.endswith(request.match, "RequestFinished")) then
      return
    end

    local msg
    if vim.endswith(request.match, "RequestStarted") then
      msg = "[CodeCompanion] in progress..."
    elseif vim.endswith(request.match, "RequestFinished") then
      msg = "[CodeCompanion] Done ✅"
    end

    vim.notify(msg, "info", {
      timeout = 1000,
      keep = function()
        return not vim.endswith(request.match, "RequestFinished")
      end,
      id = "code_companion_status",
      title = "Code Companion Status",
      opts = function(notif)
        notif.icon = ""
        if vim.endswith(request.match, "RequestStarted") then
          -- Keep the spinner animation for "in progress..." state
          notif.icon = spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
        elseif vim.endswith(request.match, "RequestFinished") then
          notif.icon = " "
        end
      end,
    })
  end,
})
