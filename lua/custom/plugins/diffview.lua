return {
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    cmd = { 'DiffviewOpen', 'DiffviewClose', 'DiffviewFileHistory' },
    keys = {
      { '<leader>gd', '<cmd>DiffviewOpen<cr>', desc = '[G]it [D]iffview Open' },
      { '<leader>gD', '<cmd>DiffviewClose<cr>', desc = '[G]it [D]iffview Close' },
      { '<leader>gH', '<cmd>DiffviewFileHistory %<cr>', desc = '[G]it File [H]istory (Diffview)' },
    },
  },
}
