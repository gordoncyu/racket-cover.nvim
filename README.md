# Racket-Cover.nvim
Shows code coverage for Racket and derived languages in Neovim

# Dependencies
`racket`, obviously
# Installation
Simply add `gordoncyu/racket-cover.nvim` to your favorite package manager. I use packer which looks like:
```lua
return packer.startup {
    function(use)
        use 'gordoncyu/racket-cover.nvim'
    end,
}
```
Then to load the plugin, call `require('racket-cover').setup()`. The function can take a table of options. The defaults are:
```lua
{
    highlight_uncovered = true, -- whether to highlight uncovered expressions or not
    uncovered_diagnostic = true, -- whether to generate diagnostics uncovered expressions or not
    coverage_dir = "/tmp/racket-cover", -- where to store coverage results
    highlight_group = { fg = "#ff0000", undercurl = true } -- how to highlight uncovered expressions
}
``` 
# Usage
This plugin provides the following commands:

`RacketCover`: takes whitespace-separated filenames and runs their test modules, using the results to show uncovered expressions in-editor. Accepts `%` for the current file.  
`RacketCoverShow`: shows uncovered expressions with highlights and/or diagnostics depending on configuration
`RacketCoverHide`: hides uncovered expression highlights/diagnostics  
`RacketCoverToggle`: toggles whether or not to show/hide uncovered expression highlights/diagnostics
