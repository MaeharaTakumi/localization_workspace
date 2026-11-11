#!/bin/bash
# src/ のリポジトリを自己位置推定コンテナ（test）に写してビルドする（ホストで実行）。
# 変更したら、コンテナで何かを実行する前に毎回これで反映する。
#
#   ./deploy.sh                          全部（下の PACKAGES と localization_tools）
#   ./deploy.sh ekf_localizer            指定したリポジトリだけ（src/ の下の名前。複数書ける）
#   ./deploy.sh --test ekf_localizer     ビルドのあと colcon test も行う
#   ./deploy.sh --mirror localization_bringup
#       コンテナ側のリポジトリと、そのパッケージの build・install を消してから写してビルドする（ホストで消した・名前を変えた
#       ファイルを、コンテナの src にも install にも残さない）。コンテナの中だけで変えたものは消えるので、付けたときだけ行う
#
# ROS のパッケージ：docker cp で /root/ros2_ws/src/<リポジトリ> に写し、所有者を root にして
#   （docker cp はホストの UID のまま置くので、直さないとコンテナ内の git が dubious ownership で止まる）、
#   colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release（イメージと同じオプション）。
# localization_tools：ROS のパッケージではないので、src/localization_tools/sync.sh push で写すだけ。
# 環境変数 LOC でコンテナの名前を変えられる（既定 test）。
set -eu
here=$(cd "$(dirname "$0")" && pwd)
LOC=${LOC:-test}
WS=/root/ros2_ws
TOOLS=localization_tools
# リポジトリ（src/ の下の名前）: colcon のパッケージ名（複数あるときは空白で区切る）
declare -A PACKAGES=(
  [ekf_localizer]=ekf_localizer
  [lidar_localization]=pcl_localization_ros2
  [lidarslam_ros2]="lidarslam_msgs ndt_omp_ros2 scanmatcher graph_based_slam lidarslam"
  [localization_bringup]=localization_bringup
  [whill_odometry]=whill_odometry
)

run_test=0; mirror=0; repos=()
for arg in "$@"; do
  case $arg in
    --test) run_test=1;;
    --mirror) mirror=1;;
    -h|--help) sed -n '2,17p' "$0"; exit 0;;
    -*) echo "unknown option: $arg"; exit 1;;
    *) repos+=("$arg");;
  esac
done
[ ${#repos[@]} -gt 0 ] || repos=("${!PACKAGES[@]}" $TOOLS)

[ "$(docker inspect -f '{{.State.Running}}' "$LOC" 2>/dev/null)" = true ] || { echo "container $LOC is not running (docker start $LOC)"; exit 1; }

packages=()
for repo in "${repos[@]}"; do
  if [ "$repo" = $TOOLS ]; then
    "$here/src/$TOOLS/sync.sh" push
    continue
  fi
  [ -n "${PACKAGES[$repo]:-}" ] || { echo "unknown repository: $repo (available: ${!PACKAGES[*]} $TOOLS)"; exit 1; }
  echo "== copy src/$repo -> $LOC:$WS/src/$repo"
  if [ $mirror = 1 ]; then
    docker exec "$LOC" rm -rf "$WS/src/$repo"
    for p in ${PACKAGES[$repo]}; do docker exec "$LOC" rm -rf "$WS/build/$p" "$WS/install/$p"; done
  fi
  docker exec "$LOC" mkdir -p "$WS/src/$repo"
  docker cp "$here/src/$repo/." "$LOC:$WS/src/$repo/"
  docker exec "$LOC" chown -R root:root "$WS/src/$repo"
  packages+=(${PACKAGES[$repo]})
done
[ ${#packages[@]} -gt 0 ] || exit 0

# コンテナの ROS の環境は ~/.bashrc で読み込まれるので bash -ic で動かす
cx() { docker exec "$LOC" bash -ic "$1" 2>&1 | grep -v "terminal process group\|no job control"; return "${PIPESTATUS[0]}"; }
echo "== build: ${packages[*]}"
cx "cd $WS && colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release --packages-select ${packages[*]}"
if [ $run_test = 1 ]; then
  echo "== test: ${packages[*]}"
  cx "cd $WS && colcon test --packages-select ${packages[*]} && colcon test-result --verbose"
fi
