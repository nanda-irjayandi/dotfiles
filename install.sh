#!/bin/sh

detect_package_manager() {
	# declare array

	managers='
	brew:brew
	nix:nix
	apt:apt-get
	dnf:dnf
	pacman:pacman
	yum:yum
	zypper:zypper
	pkg:pkg
	'

	for line in $managers; do
		name=$(echo "$line" | cut -d: -f1)
		cmd=$(echo "$line" | cut -d: -f2)
		if command -v "$cmd" >/dev/null 2>&1; then
			echo "$cmd"
			return 0
		fi
	done

	return 1
}

has_curl() {
	command -v curl >/dev/null 2>&1
}

has_brew() {
	command -v brew >/dev/null 2>&1
}

has_zsh() {
	command -v zsh >/dev/null 2>&1
}

has_git() {
	command -v git >/dev/null 2>&1
}

install_curl() {
	if ! has_curl; then
		echo "cURL not found. Install it now? [y/N]"
		read answer
		case "$answer" in
		[yY]*)
			pkgmgr=$(detect_package_manager)

			if [ -z "$pkgmgr" ]; then
				echo "ERROR: No supported package manager"
				return 1
			fi

			echo "Installing cURL with $pkgmgr"

			case "$pkgmgr" in
			apt-get)
				apt-get update && apt-get upgrade && apt-get install -y curl
				;;
			dnf | yum | zypper)
				"$pkgmgr" install -y curl
				;;
			pacman)
				pacman -Sy --noconfirm curl
				;;
			brew)
				brew install curl
				;;
			pkg)
				pkg install curl
				;;
			*)
				echo "ERROR: cannot install curl with $pkgmgr"
				return 1
				;;
			esac

			if ! has_curl; then
				echo "ERROR: curl failed to install with $pkgmgr"
				echo "Review https://curl.se/docs/install.html"
				return 1
			fi
			;;
		*)
			echo "cURL installation skipped."
			;;
		esac
	fi
	return 0
}

install_brew() {
	if has_brew; then
		echo "NOTICE: Homebrew installed. Run brew --help for further information"
		echo "$(brew --version)"
		return 0
	else
		echo "Homebrew not found. Install it now? [y/N]"
		read answer
		case "$answer" in
		[Yy]*)
			NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
			echo "NOTICE: Homebrew installed. Run brew --help for further information"
			echo "$(brew --version)"
			;;
		*)
			echo "Homebrew installation skipped."
			;;
		esac
	fi

	return 0

}

install_zsh() {
	if has_zsh; then
		echo "[INFO] Zsh found"
		echo "$(zsh --version)"
		echo "Run chsh -s $(which zsh) to set Zsh as default"
		return 0
	else
		echo "Zsh not found. Install it now? [y/N]"
		read answer
		case "$answer" in
		[yY]*)
			if has_brew; then
				brew install zsh
			else
				echo "[NOTICE] Homebrew package manager recommended"
				echo "https://github.com/ohmyzsh/ohmyzsh/wiki/Installing-ZSH"
				return 1
			fi
			;;
		*)
			echo "Zsh installation skipped."
			;;
		esac

	fi
	return 0
}

install_git() {
	if ! has_git; then
		if has_brew; then
			brew install git
		else
			echo "[NOTICE] Homebrew package manager recommended"
			echo "https://git-scm.com/downloads"
			return 1
		fi
	fi
}

call_deploy() {
	if has_brew && has_curl && has_git && has_zsh; then
		DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
		export DOTFILES_DIR
		exec zsh "$DOTFILES_DIR/source/00_deploy.zsh"
	else
		echo "ERROR: Missing one or more requirements (brew, curl, git, zsh)"
		return 1
	fi
}

main() {
	install_curl || exit 1
	install_brew || exit 1
	install_git || exit 1
	install_zsh || exit 1
	call_deploy
}

main "$@"
