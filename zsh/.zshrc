# @source: https://github.com/z0rc/dotfiles/blob/main/zsh/.zshrc

# Include interactive rc files
for conffile in "${ZDOTDIR}"/rc.d/*; do
    source "${conffile}"
done

unset conffile