#!/bin/sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
output_dir="$project_root/build"
package_path="$output_dir/roku-caster.zip"

mkdir -p "$output_dir"
cd "$project_root"
zip -q -r -X "$package_path" manifest source components images

printf 'Pacote Roku criado em: %s\n' "$package_path"
