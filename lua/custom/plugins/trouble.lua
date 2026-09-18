return {
  {
    'folke/trouble.nvim',
    cmd = 'Trouble',
    opts = {},
    keys = {
      { '<leader>xx', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Diagnostics (Trouble)' },
      { '<leader>xw', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer Diagnostics (Trouble)' },
      { '<leader>xq', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix List (Trouble)' },
      { '<leader>xr', '<cmd>Trouble lsp_references toggle<cr>', desc = 'LSP References (Trouble)' },
    },
  },
}
