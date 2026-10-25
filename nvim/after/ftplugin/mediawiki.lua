-- Neovim's bundled mediawiki ftplugin enables foldexpr/foldmethod=expr, which
-- collapses every == section == on open (foldlevel defaults to 0). Operators
-- then act on whole closed folds, so edits near a heading silently fold the
-- section away. Keep the other ftplugin settings, drop the folding.
vim.opt_local.foldmethod = "manual"
