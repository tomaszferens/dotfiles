return {
  "olimorris/codecompanion.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { "MeanderingProgrammer/render-markdown.nvim", ft = { "markdown", "codecompanion" } },
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
