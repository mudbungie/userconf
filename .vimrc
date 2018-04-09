" scrap autocmds from env, if any
autocmd!

" initialize pathogen, for imports
"call pathogen#incubate

" colors!
color zellner 

set nocompatible "if I wanted vi, I'd use it
"set hidden "not sure about this... 
set history=10000

" default; changed in filetype-specifics
set expandtab 
set tabstop=4
set softtabstop=4
set shiftwidth=4
set autoindent
set smarttab "experimenting #TODO review

" delete whatever in insert
set backspace=indent,eol,start
"set backspace=2 "dumb

" always show status bar
set laststatus=2
" and don't hold command section open
set cmdheight=1

" searching
set incsearch "search on all keypresses, not return
set hlsearch "highlight all matches
set ignorecase smartcase "only case-sensitive if caps included

" visual editor decorators
set ruler
set number
set cursorline " horizontal rule on active line

" syntax parsing
syntax enable "preserves custom definition, vs on

" folding
set foldenable " folding, default toggle for a fold is za
set foldlevelstart=10 " don't go folding shallow nests by default
set foldnestmax=10 " a precaution against runaway folds
nnoremap <space> za

" prefer more private tmps
set backupdir=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp
set directory=~/.vim-tmp,~/.tmp,~/tmp,/var/tmp,/tmp

" filetype-specific tab behaviors
au FileType python setl sw=4 sts=4 et
au FileType ruby setl sw=2 sts=2 noet
au FileType javascript setl sw=2 sts=2 noet
au FileType json setl sw=2 sts=2 noet

" still not sure about these
"set wildmenu " shows possibilities for tab-completion
"set showmatch " highlight matching paired operators
"hi MatchParen cterm=bold ctermfg=black
"set showcmd

