set nocompatible              " be iMproved, required
filetype off                  " required

" Vim needs a POSIX-Compliant shell. Fish is not.
" Removing this will cause Vundle to give you \"Error fetching scripts!\".
if $SHELL =~ 'bin/fish'
    set shell=/bin/sh
endif

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'

" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
Plugin 'bling/vim-airline'

" Add vim-superman to view man pages using vim instead of with less
Plugin 'Z1MM32M4N/vim-superman'

" plugin from http://vim-scripts.org/vim/scripts.html
" Plugin 'L9'
" Git plugin not hosted on GitHub
" Plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
" Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
" Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
" Avoid a name conflict with L9
" Plugin 'user/L9', {'name': 'newL9'}

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on

"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line


" Some cool settings which make vim bearable
set incsearch		" do incremental searching
set showcmd		" display incomplete commands
set autoindent		" always set autoindenting on
set hlsearch		" highlight matched patterns
set wrap linebreak nowrap " Nice wordwrap for vman
syntax on " Color highlighting

" Make the vim-airline status line appear all the time.
set laststatus=2

" This did not work out -- we leave this fight to another day
" Use powerline fonts
"set guifont=Literation\ Mono\ Powerline

" Make vim-airline use powerline fonts
"let g:airline_powerline_fonts=1

"if !exists('g:airline_symbols')
"  let g:airline_symbols = {}
"endif
"let g:airline_symbols.space = "\ua0"

"set ambiwidth=double

" Copied from http://www.vim.org/scripts/script.php?script_id=3600
" Requires you to download file ~/.vim/syntax/octave.vim
" Octave syntax
augroup filetypedetect
  au! BufRead,BufNewFile *.m,*.oct set filetype=octave
augroup END

" Use keywords from Octave syntax language file for autocomplete
if has("autocmd") && exists("+omnifunc")
   autocmd Filetype octave
   \    if &omnifunc == "" |
   \    setlocal omnifunc=syntaxcomplete#Complete |
   \    endif
endif
