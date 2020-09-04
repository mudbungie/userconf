color zellner 
set ruler
set backspace=2
set number
syntax on
set tabstop=4
set shiftwidth=4
set smarttab
set expandtab
set autoindent
set cursorline " horizontal rule on active line
set wildmenu " shows possibilities for tab-completion
set showmatch " highlight matching paired operators
set incsearch " search as I type the search criteria, not just when I hit enter
set hlsearch " highlight search matches
set visualbell " fuck bells

hi MatchParen cterm=bold ctermfg=black

au FileType python setl sw=4 sts=4 et
au FileType ruby setl sw=2 sts=2 noet
au FileType javascript setl sw=2 sts=2 noet
au FileType json setl sw=2 sts=2 et
