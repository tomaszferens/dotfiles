return {
  "esmuellert/codediff.nvim",
  cmd = "CodeDiff",
  keys = {
    { "<C-g>", "<CMD>CodeDiff<CR>", desc = "Git diff explorer" },
    { "<leader>gf", "<CMD>CodeDiff history HEAD~40 %<CR>", desc = "File commit history (last 40)" },
    { "<leader>ghh", "<CMD>CodeDiff history<CR>", desc = "Git commit history" },
  },
  config = function()
    require("codediff").setup({
      keymaps = {
        view = {
          open_in_prev_tab = false,
        },
      },
    })

    local function set_gf_keymaps()
      local diff_tab = vim.api.nvim_get_current_tabpage()
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(diff_tab)) do
        local buf = vim.api.nvim_win_get_buf(win)
        vim.keymap.set("n", "gf", function()
          local name = vim.api.nvim_buf_get_name(0)
          local line = vim.fn.line(".")
          -- If current buffer is virtual (git revision), find a real file in the tab
          if name == "" or vim.fn.filereadable(name) ~= 1 then
            for _, w in ipairs(vim.api.nvim_tabpage_list_wins(diff_tab)) do
              local n = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w))
              if n ~= "" and vim.fn.filereadable(n) == 1 then
                name = n
                break
              end
            end
          end
          vim.cmd("tabclose")
          if name ~= "" and vim.fn.filereadable(name) == 1 then
            vim.cmd(string.format("edit +%d %s", line, vim.fn.fnameescape(name)))
          end
        end, { buffer = buf, desc = "Open file and close diff" })
      end
    end

    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffOpen",
      callback = set_gf_keymaps,
    })
    vim.api.nvim_create_autocmd("User", {
      pattern = "CodeDiffFileSelect",
      callback = function()
        vim.schedule(set_gf_keymaps)
      end,
    })
  end,
}
