return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "MeanderingProgrammer/render-markdown.nvim", ft = { "markdown", "codecompanion" } },
    "ravitemer/codecompanion-history.nvim",
  },
  event = "VeryLazy",
  opts = {
    extensions = {
      mcphub = {
        callback = "mcphub.extensions.codecompanion",
        opts = {
          show_result_in_chat = true, -- Show mcp tool results in chat
          make_vars = true, -- Convert resources to #variables
          make_slash_commands = true, -- Add prompts as /slash commands
        },
      },
      history = {
        enabled = true,
        opts = {
          -- Keymap to open history from chat buffer (default: gh)
          keymap = "gh",
          -- Automatically generate titles for new chats
          auto_generate_title = true,
          ---On exiting and entering neovim, loads the last chat on opening chat
          continue_last_chat = false,
          ---When chat is cleared with `gx` delete the chat from history
          delete_on_clearing_chat = false,
          -- Picker interface ("telescope" or "snacks" or "default")
          picker = "snacks",
          ---Enable detailed logging for history extension
          enable_logging = false,
          ---Directory path to save the chats
          dir_to_save = vim.fn.stdpath("data") .. "/codecompanion-history",
          -- Save all chats by default
          auto_save = true,
          -- Keymap to save the current chat manually
          save_chat_keymap = "sc",
        },
      },
    },
    opts = {
      log_level = "DEBUG", -- TRACE|DEBUG|ERROR|INFO
      system_prompt = function(opts)
        return require("utils.code_companion.get_system_prompt").get_system_prompt(opts)
      end,
    },
    display = {
      diff = {
        provider = "mini_diff",
      },
      chat = {
        show_settings = true,
      },
    },
    strategies = {
      chat = {
        adapter = {
          name = "copilot",
          model = "claude-sonnet-4",
        },
        roles = {
          llm = function(adapter)
            return "CodeCompanion (" .. adapter.formatted_name .. ")"
          end,
          user = "Me",
        },
        tools = {
          opts = {
            auto_submit_errors = true, -- Send any errors to the LLM automatically?
            auto_submit_success = true, -- Send any successful output to the LLM automatically?
          },
        },
        keymaps = {
          close = {
            modes = {
              n = "q",
            },
            index = 3,
            callback = "keymaps.close",
            description = "Close Chat",
          },
          stop = {
            modes = {
              n = "<C-c>",
            },
            index = 4,
            callback = "keymaps.stop",
            description = "Stop Request",
          },
        },
      },
      inline = {
        adapter = {
          name = "copilot",
          model = "claude-sonnet-4",
        },
      },
    },
  },
  config = function(_, opts)
    vim.g.codecompanion_auto_tool_mode = true
    require("codecompanion").setup(opts)
    require("utils.code_companion.extmarks").setup()
    require("utils.code_companion.progress")

    local map = LazyVim.safe_keymap_set

    map("v", "<leader>ad", [[:'<,'>CodeCompanionChat Add<CR>]], { noremap = true, silent = true })
    map(
      { "n", "v" },
      "<leader>ac",
      "<cmd>CodeCompanionActions<cr>",
      { noremap = true, silent = true, desc = "CodeCompanion actions" }
    )
    map(
      { "n", "v" },
      "<leader>aa",
      "<cmd>CodeCompanionChat Toggle<cr>",
      { noremap = true, silent = true, desc = "CodeCompanion chat" }
    )
    map("v", "<leader>ae", function()
      vim.ui.input({
        prompt = "Enter prompt: ",
        relative = "cursor",
        override = function(conf)
          conf.anchor = "NW"
          conf.row = 1
          return conf
        end,
      }, function(prompt)
        if not prompt or prompt == "" then
          print("No prompt given. Aborting.")
          return
        end
        vim.cmd(
          "'<,'>CodeCompanion Please edit the selected code. Here is the full #{buffer} code for reference. " .. prompt
        )
      end)
    end, { noremap = true, silent = true, desc = "Edit" })
    map({ "n" }, "<leader>ab", function()
      local relative_buffer_path = vim.fn.expand("%:.")
      vim.cmd("CodeCompanionChat")
      vim.cmd("startinsert")
      vim.api.nvim_feedkeys(
        " I'm currently looking at this file: #{buffer} " .. "(" .. relative_buffer_path .. ")" .. ".\n\n",
        "n",
        true
      )
    end, { noremap = true, silent = true, desc = "Chat with buffer" })
    map({ "n" }, "<leader>ae", function()
      local relative_buffer_path = vim.fn.expand("%:.")
      vim.cmd("CodeCompanionChat")
      vim.cmd("startinsert")
      vim.api.nvim_feedkeys(
        "You have the capability to @{insert_edit_into_file}\n\nI'm currently looking at this file: #{buffer} "
          .. "("
          .. relative_buffer_path
          .. ").\n\nHelp me with the following:\n\n",
        "n",
        true
      )
    end, { noremap = true, silent = true, desc = "Edit buffer" })
    map({ "n" }, "<leader>af", function()
      local relative_buffer_path = vim.fn.expand("%:.")
      vim.cmd("CodeCompanionChat")
      vim.cmd("startinsert")
      vim.api.nvim_feedkeys(
        "You're a @{full_stack_dev} with access to MCP (@{mcp}) servers.\n\nI'm currently looking at this file: #{buffer} "
          .. "("
          .. relative_buffer_path
          .. ").\n\nPlease help me with the following:\n\n",
        "n",
        true
      )
    end, { noremap = true, silent = true, desc = "Chat with buffer" })
  end,
}
