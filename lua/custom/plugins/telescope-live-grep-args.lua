return {
  {
    'nvim-telescope/telescope-live-grep-args.nvim',
    dependencies = { 'nvim-telescope/telescope.nvim' },
    config = function()
      require('telescope').load_extension 'live_grep_args'
      vim.keymap.set('n', '<leader>sG', function()
        require('telescope').extensions.live_grep_args.live_grep_args()
      end, { desc = '[S]earch by [G]rep (Args)' })
    end,
  },
}
