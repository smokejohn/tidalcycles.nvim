# tidalcycles.nvim

A modern lua plugin for [TidalCycles](https://tidalcycles.org) for neovim.

This plugin aims to reach a state where it supplies the same functionality as [vim-tidal](https://github.com/tidalcycles/vim-tidal) or the plugin for the [Pulsar Text Editor](https://github.com/tidalcycles/pulsar-tidalcycles).


## Installation

```lua
-- lazy.nvim
{
  'smokejohn/tidalcycles.nvim',
}
```

This will load the plugin with its default configuration.
```lua
require('tidalcycles').setup{
    boot = {
        tidal = {
            file = vim.api.nvim_get_runtime_file("BootTidal.hs", false)[1],
            args = {},
        },
        sclang = {
            file = vim.api.nvim_get_runtime_file("BootSuperDirt.scd", false)[1],
            enabled = false,
        },
        split = 'v',
    },
    keymaps = {
        send_line = "<C-E>",
        send_visual = "<C-E>",
        hush = "<C-M>"
    }
}
```

## Requirements

To use this plugin a few dependencies have to be installed on the system:

* Haskell
* SuperCollider
* SuperDirt
* TidalCycles

The plugin assumes you can access `ghci` and `sclang` on the commandline.
Opening the Glasgow Haskell Compiler (ghci) on the commandline and typing `import Sound.Tidal.Context` should work and report no errors.

## Usage

Start or stop a TidalCycles session by using either the `:TidalStart` or `:TidalStop` commmand.


## Keymaps

`tidalcycles.nvim` provides the following default keymaps inside `.tidal` files:

`Ctrl + E` in *normal* mode to evaluate the current line
`Ctrl + E` in *visual* selection mode to evaluate the selected lines
`Ctrl + M` to stop playback via `hush` command


## Misc

This plugin builds upon the work of Robbie Lyman's now archived [tidal.nvim](https://github.com/robbielyman/tidal.nvim)
