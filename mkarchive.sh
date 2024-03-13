#!/bin/env argscript

declare -A args=(
	[directory]=''
	[outfile]='/dev/stdout'
)

Usage() {
	cat <<EOD
Usage: $(basename "${BASH_SOURCE[0]}") [OPTIONS] DIRECTORY

Options:
  --outfile FILENAME        Write the archive to this file.
  --help                    Show this message and exit.

Creates an xz tar archive of an installed filesystem.
EOD
}

Argument() {
  local name=$1
  local type=$2
  local value=$3

	if [[ "$name" ]]; then
		[[ "$value" ]] && args["$name"]="$value" || args["$name"]=true
	else
		args[directory]="$value"
	fi
}

Main() {
  if [[ ! "${args[directory]}" || ! -d "${args[directory]}" ]]; then
		error "DIRECTORY is required and must exist."
		return 1
  fi

	tar --create --one-file-system --preserve-permissions --file="${args[outfile]}" --xz --directory="${args[directory]}" .
}

error() {
	>&2 printf "$(tput setaf 1)error:$(tput sgr0) %s\n" "$*"
}
