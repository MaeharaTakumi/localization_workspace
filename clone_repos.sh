#!/bin/bash
# repos.yaml のリポジトリを clone する（すでにあるものは何もしない）。このリポジトリの直下で実行する
set -eu
cd "$(dirname "$0")"
python3 - <<'PY' | while read -r path url branch; do
import yaml
for r in yaml.safe_load(open('repos.yaml'))['repos']:
    print(r['path'], r['url'], r['branch'])
PY
  if [ -d "$path/.git" ]; then
    echo "skip  $path（ある）"
  else
    mkdir -p "$(dirname "$path")"
    git clone --recursive -b "$branch" "$url" "$path"   # lidarslam_ros2 はサブモジュール（ndt_omp_ros2）を持つ
  fi
done
