vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent",
  callback = function(args)
    if args.data.type == "session.idle" then
      vim.notify("opencode finished responding", vim.log.levels.INFO)
    end
  end,
})

return {
  "NickvanDyke/opencode.nvim",
  dependencies = {
    -- Recommended for better prompt input, and required to use opencode.nvim's embedded terminal — otherwise optional
    { "folke/snacks.nvim", opts = { input = { enabled = true } } },
  },
  ---@type opencode.Opts
  opts = {
    -- Your configuration, if any — see lua/opencode/config.lua
  },
  keys = {
    {
      "<leader>oA",
      function()
        require("opencode").ask()
      end,
      desc = "Ask opencode",
    },
    {
      "<leader>oa",
      function()
        require("opencode").ask("@cursor: ")
      end,
      desc = "Ask opencode about this",
      mode = "n",
    },
    {
      "<leader>oa",
      function()
        require("opencode").ask("@selection: ")
      end,
      desc = "Ask opencode about selection",
      mode = "v",
    },
    {
      "<M-o>",
      function()
        require("opencode").toggle()
      end,
      desc = "Toggle embedded opencode",
    },
    {
      "<leader>on",
      function()
        require("opencode").command("session_new")
      end,
      desc = "New session",
    },
    {
      "<leader>oy",
      function()
        require("opencode").command("messages_copy")
      end,
      desc = "Copy last message",
    },
    {
      "<S-C-u>",
      function()
        require("opencode").command("messages_half_page_up")
      end,
      desc = "Scroll messages up",
    },
    {
      "<S-C-d>",
      function()
        require("opencode").command("messages_half_page_down")
      end,
      desc = "Scroll messages down",
    },
    {
      "<leader>op",
      function()
        require("opencode").select_prompt()
      end,
      desc = "Select prompt",
      mode = { "n", "v" },
    },
    -- Example: keymap for custom prompt
    {
      "<leader>oe",
      function()
        require("opencode").prompt("Explain @cursor and its context")
      end,
      desc = "Explain code near cursor",
    },
  },
}
