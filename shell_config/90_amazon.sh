if hostname -f |grep -q 'amazon.com' ; then
    add_to_path "$HOME/.toolbox/bin"
    add_to_path '/apollo/env/SDETools/bin'
    add_to_path '/apollo/env/envImprovement/bin'
    add_to_path '/apollo/bin'
    add_to_path '/apollo/sbin'
    add_to_path '/apollo/env/ApolloCommandLine/bin'
    add_to_path '/apollo/env/AmazonAwsCli/bin'
    add_to_path '/apollo/env/OdinTools/bin'
    add_to_path '/usr/kerberos/bin'
    add_to_path '/apollo/env/OctaneBrazilTools/bin'
    add_to_path '/apollo/env/BrazilCLI/public-bin/brazil'

    mac_compliant_inline_sed 's/mudbungie/oribi/g' ~/.gitconfig
    mac_compliant_inline_sed 's/gmail/amazon/g' ~/.gitconfig
    
    alias bo='brazil-octane'
    alias mwinit='mwinit -o'
    alias bre='brazil-runtime-exec'
fi