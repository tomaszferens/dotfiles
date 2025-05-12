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
      vectorcode = {
        opts = { add_tool = true, add_slash_command = true, tool_opts = {} },
      },
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
    adapters = {
      anthropic = function()
        return require("codecompanion.adapters").extend("anthropic", {
          env = {
            api_key = "ANTHROPIC_API_KEY",
          },
          schema = {
            model = {
              default = "claude-3-7-sonnet-20250219",
            },
            extended_thinking = {
              default = false,
            },
          },
        })
      end,
    },
    strategies = {
      chat = {
        adapter = "anthropic",
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
        adapter = "anthropic",
      },
    },
  },
}
