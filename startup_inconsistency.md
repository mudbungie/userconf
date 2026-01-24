 # Bash startup inconsistency on macOS Terminal
 
 Summary
 - New Terminal windows (login bash) did not load custom "bash goodies" from ~/.bashrc. Manually typing `bash` (non-login interactive) did load them, resulting in different prompts and messages.
 
 Diagnosis (key evidence)
 - Login shell: dscl shows UserShell: /bin/bash.
 - Files: ~/.bashrc exists with custom setup (sources ~/userconf/shell_config, defines `alias scm-ssh=~/.ssh/scm-script.sh`, invokes `scm-ssh start_agent`, sets PS1, loads nvm).
 - No ~/.bash_profile was present initially, so login bash did not source ~/.bashrc.
 - macOS behavior: Terminal launches bash as a login shell (reads /etc/profile → /etc/bashrc and ~/.bash_profile), whereas a non-login interactive bash reads ~/.bashrc.
 - Repro: `bash -il` shows custom alias and SSH agent messages; plain new Terminal did not until fixed.
 
 Root cause
 - Missing ~/.bash_profile "bridge" to source ~/.bashrc for login shells.
 
 - If you switch to zsh (`chsh -s /bin/zsh`), mirror the `~/.bashrc` logic in `~/.zshrc`.
