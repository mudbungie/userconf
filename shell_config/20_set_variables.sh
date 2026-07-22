# Enable the color shortcuts. Preceding bash_functions may break without this.
bash_colors

# Enforce color settings
force_color_prompt=yes
color_prompt=yes

# Add my local bins to the path.
prepend_to_path "$HOME/bin"
prepend_to_path "$HOME/.local/bin"

# Use vim.
EDITOR=vim
VISUAL=$EDITOR
