color zellner 
set ruler
set backspace=2
set number
syntax on
set tabstop=2
set shiftwidth=2
set smarttab
set autoindent
set cursorline " horisontal rule on active line
set wildmenu " shows possibilities for tab-completion
set showmatch " highlight matching paired operators
set incsearch " search as I type the search criteria, not just when I hit enter
set hlsearch " highlight search matches
set foldenable " folding, default toggle for a fold is za
set foldlevelstart=10 " don't go folding shallow nests by default
set foldnestmax=10 " a precaution against runaway folds
nnoremap <space> za
hi MatchParen cterm=bold ctermfg=black
