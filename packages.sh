#!/bin/env argscript

# PACKAGES that constitute a base install
declare BASE=(base iptables-nft polkit)

local groups=()
local PACKAGES=()
declare -A args=(
	[directory]=''
	[language]="$LANG"
	[hostname]='jwix'
	[timezone]="$(realpath --relative-to /usr/share/zoneinfo "$(readlink /etc/localtime)")"
)
local HERE="$(dirname "${BASH_SOURCE[0]}")"
Usage() {
	cat <<EOD
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] DIRECTORY [GROUP...]

Options:
  --help                    Show this message and exit.
  --language LANGUAGE       Installation language.
  --hostname STRING         The system hostname.
  --timezone STRING         The system timezone.

Installs PACKAGES into a root filesystem.

An example script for the argument processor.
EOD
}

Argument() {
  local name=$1
  local type=$2
  local value=$3

  if [[ "$1" ]]; then
	  [[ "$3" ]] && args["$1"]="$3" || args["$1"]=true
  else
		if [[ "${args[directory]}" ]]; then
			groups+=("$3")
		else
			args[directory]="$3"
		fi
  fi
  return 0
}

Main() {
  if [[ ! "${args[directory]}" || ! -d "${args[directory]}" ]]; then
		error "DIRECTORY is required and must exist."
		return 1
  fi

  if [[ ! -x "${args[directory]}/usr/bin/pacman" ]]; then
	  # base doesn't seem to be installed
	  pacstrap -ciK "${args[directory]}" "${BASE[@]}"
	  configure glibc
  fi

  # add groups to package list
  for group in "${groups[@]}"; do
	if [[ ! -f "$HERE/groups/${group}" ]]; then
	  error "no group named $group"
	  return 1
	fi
	# shellcheck disable=SC1090
	. "$HERE/groups/${group}"
  done

  if [[ ! "${PACKAGES[*]}" ]]; then
		return 0
  fi

	mount --bind /var/cache/pacman/pkg "${args[directory]}/var/cache/pacman/pkg"
  exec-chroot pacman -Su --needed "${PACKAGES[@]}"

	# configure installed packages
	# shellcheck disable=SC2046
	configure $(exec-chroot pacman -Qq)
	umount "${args[directory]}/var/cache/pacman/pkg"

  # diagnostics
  echo
  for key in "${!args[@]}"; do
	  printf "$(tput setaf 2)%s$(tput sgr0): %s\n" "$key" "${args[$key]}"
  done
  printf "%i groups: %s\n" ${#groups[@]} "${groups[*]}"

  printf "%i arguments remaining: %s\n" $# "$*"
}

error() {
	>&2 printf "$(tput setaf 1)error:$(tput sgr0) %s\n" "$*"
}

exec-chroot() {
  arch-chroot "${args[directory]}" "$@"
}

configure() {
	local pkg
	for pkg in "$@"; do
		if [[ -r "$HERE/config/$pkg" ]]; then
			printf "$(tput setaf 2)Configuring %s$(tput sgr0)\n" "$pkg"
			# shellcheck disable=SC1090
			. "$HERE/config/$pkg"
			config
		fi
	done
}

original() {
	local file pkgname archive
	file="$(exec-chroot readlink -f "$1")"
	pkgname="$(exec-chroot pacman -Qoq "$file")"
	archive="$(exec-chroot pacman -S --print-format "%l" "$pkgname")"
	tar -xf "${archive#file://}" --zstd --to-stdout "${file#/}" > "${args[directory]}/$1"
}

git-repo() {
	local d="${args[directory]}/etc/skel"
	mkdir -p "$d/$(dirname "$1")"
	if [[ -d "$d/$1" ]]; then
		git -C "$d/$1" pull
	else
		git -C "$d/$(dirname "$1")" clone --quiet --recurse-submodules "$2" "$(basename "$1")"
	fi

	local statedir="$d/.local/state"
	mkdir -p "$statedir"
	[[ ! -f "$statedir/user_config_dirs" ]] && touch "$statedir/user_config_dirs"
	grep -q "$1" "$statedir/user_config_dirs" || echo "$1" >> "$statedir/user_config_dirs"
}

# vim: ft=bash
