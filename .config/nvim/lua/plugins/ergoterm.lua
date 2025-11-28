return {
  "waiting-for-dev/ergoterm.nvim",
  config = function()
    local ergoterm = require("ergoterm")
    ergoterm.setup()

    local ai_chats = ergoterm.with_defaults({
      layout = "right",
      tags = { "ai_chat" },
      auto_list = false,
      bang_target = false,
      sticky = true,
      watch_files = true,
      size = {
        right = "50%",
      },
    })

    ai_chats:new({
      cmd = "claude",
      name = "claude",
      meta = {
        add_file = function(file)
          return "@" .. file .. " "
        end,
      },
    })

    ai_chats:new({
      cmd = "opencode",
      name = "opencode",
      meta = {
        add_file = function(file)
          return "@" .. file
        end,
      },
    })
  end,
  keys = {
    {
      "<c-.>",
      function()
        require("utils.ai").toggle("claude")
      end,
      desc = "Toggle Claude",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<M-c>",
      function()
        require("utils.ai").toggle("claude")
      end,
      desc = "Toggle Claude",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<M-o>",
      function()
        require("utils.ai").toggle("opencode")
      end,
      desc = "Toggle OpenCode",
      mode = { "n", "t", "i", "x" },
    },
    {
      "<M-a>",
      function()
        require("utils.ai").send({ msg = "{file}" })
      end,
      desc = "Add file to AI",
    },
    {
      "<M-a>",
      function()
        require("utils.ai").send_visual_selection_to_ai_terminals()
      end,
      desc = "Add file to AI",
      mode = { "x", "v" },
    },
    {
      "<S-CR>",
      function()
        require("utils.ai").send({ msg = "\n" })
      end,
      desc = "New line",
      mode = { "t" },
    },
    {
      "<leader>af",
      function()
        require("utils.ai").send({ msg = "{file}" })
      end,
      desc = "Send File",
    },
    {
      "<leader>av",
      function()
        require("utils.ai").send({ msg = "{selection}" })
      end,
      mode = { "x" },
      desc = "Send Selection",
    },
  },
}
