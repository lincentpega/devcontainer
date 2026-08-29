return {
  {
    "mfussenegger/nvim-jdtls",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      root_dir = function(path)
        return vim.fs.root(path, vim.lsp.config.jdtls.root_markers)
          or vim.fs.root(vim.fn.getcwd(), vim.lsp.config.jdtls.root_markers)
      end,
      on_attach = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        client.server_capabilities.documentFormattingProvider = false
        client.server_capabilities.documentRangeFormattingProvider = false
      end,
    },
  },
}
