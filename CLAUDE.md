# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

今の仕様と作業の決まりだけを書く。経緯（いつ・なぜ変えたか、比べた数値）は `dev_log.md` に任せ、ここには番号で参照する
（2026-11-11 にユーザー指示で整理した。それまでの全文は git の履歴 `8023d05` 以前にある）。

## 厳守事項（ユーザー指示）

- **回答は日本語で書く**。
- **Gazebo コンテナ `20261002` のファイルは、ユーザーの許可なしに編集しない**（読むのは可）。問題を Gazebo 側の設定変更で解決しない。
  許可を得て変えたものは `gazebo_changes.md` に記録する（**Gazebo を変えたら必ず追記する**）。
- **既存の自作 EKF（`ekf_localizer`）とその起動方法を壊さない。`ekf_localizer` リポジトリはユーザーが指示したときだけ変更する**
  （変更の履歴は `dev_log.md`。最近は 74・79・80・82・83）。
- **曖昧な点は自分で判断せず、必ずユーザーに質問する。**
- **作業がひと区切りついたら（動作を確かめ、開発ログ・README を直したら）、確認を取らずに commit して push する**
  （変更したリポジトリごと。push したら commit を報告する）。
- **パラメータの置き場所**（2026-11-11、ユーザー指示）：各パッケージ（ekf_localizer・lidar_localization・whill_odometry）はパラメータファイルを
  持たない。環境ごとの値は localization_bringup の `param/<env>/<ノード名>.yaml`（SLAM は `lidarslam.yaml`）に**全項目を書く**
  （lidarslam_ros2 のパッケージ側の `lidarslam/param/lidarslam.yaml` はパッケージ単体の launch 用に残す。2026-11-12、ユーザー指示）。yaml の無いノード・書いていない項目、
  env を指定しない起動は、各ノードのコードの既定値で動く（コードの既定は今の値に合わせてある。ただし環境で決まる値（取付・地図・初期姿勢・
  オドメトリの倍率・Gazebo の基準フレーム）と、ekf_localizer の `tf_future_steps`・`tf_past_steps`（コード 0・0、環境は 4 つとも 2・1）は yaml にだけある）。
- **変更したら、実行する前に毎回反映する**：`src/` のリポジトリを変えたら、`test` で何かを実行する前に `./deploy.sh <リポジトリ>`
  （写す・chown・`colcon build`。localization_tools は `sync.sh push`）。ファイルを消した・名前を変えたときは `--mirror`。
  `docker/`（localizer_docker）を変えたら、**確認を取らずに**イメージを再ビルドして `test` を作り直す（下の「コンテナを作り直す」）。
  推定を動かしているときは止めてから行う。
- GitHub リポジトリの作成はユーザーの確認を取ってから。イメージの再ビルドとコンテナの作り直しは、上の場合以外は確認を取る。
- **開発ログ `dev_log.md` に、作業したら日付・項目ごとに末尾へ追記する**。各項目は目的・やったこと・結果（数値）・図。説明は簡潔に。
  図は `results/` から `dev_log_images/` に写して埋め込む。
- **パラメータ推定の名前は calibration を基準にする**（プログラム・変数・コマンドに estimate を入れない）。

## 作業場所の構成

`Docker/localization/` はホスト側の作業場所。リポジトリを `src/` に clone して編集し、`deploy.sh` で自己位置推定コンテナ `test` に反映して、
ビルド・実行はコンテナの中で行う（ホストに ROS は無い）。ROS 2 Humble / Ubuntu 22.04。今後 localization 以外の Docker も `Docker/<名前>/` に同じ形で並べる。

| 場所 | 中身 | git |
|---|---|---|
| `./` | `CLAUDE.md`・`README.md`・`dev_log.md`・`gazebo_changes.md`・`dev_log_images/`・`repos.yaml`・`clone_repos.sh`・`deploy.sh` | **`MaeharaTakumi/localization_workspace`**（Public、main）。`.gitignore` で `src/`・`docker/`・`archive/`・`results/`・地図・動画を外す |
| `src/` | 開発中のリポジトリ（下表）と MATLAB | それぞれ単独のリポジトリ（`repos.yaml`、`./clone_repos.sh` で clone） |
| `docker/` | Docker 定義と `data/{bags,map,fig}`（録画・地図・図。git の外） | `MaeharaTakumi/localizer_docker`（main） |
| `results/` | 描いた図すべて（`sync.sh pull` の行き先） | なし |
| `archive/` | 使っていないもの（`localizer_ekf_docker` など） | なし |

| `src/` のリポジトリ | ブランチ | パッケージ名 | 中身 |
|---|---|---|---|
| `localization_bringup` | humble | 同じ | launch と環境ごとの設定 `param/<env>/`（各ノードの yaml もここ） |
| `lidar_localization` | humble | `pcl_localization_ros2` | NDT |
| `lidarslam_ros2` | humble | `scanmatcher`・`graph_based_slam`・`lidarslam`・`lidarslam_msgs`・`ndt_omp_ros2`（サブモジュール） | SLAM（地図作り）。2026-11-12 から `src/` に置く |
| `ekf_localizer` | humble | 同じ | 11 状態 EKF（ROS 非依存の本体 + ノード、gtest 3 つ） |
| `whill_odometry` | humble | 同じ | 実機の車輪オドメトリ |
| `localization_tools` | main | （ROS のパッケージではない） | 検証・調整・描画・テスト走行・パラメータ推定 |
| `whill_common_matlab-main _ndtDebug` | `cr_debug` | — | MATLAB（下記） |

- `rviz2_bag` は外部のリポジトリ。
- **MATLAB**（`src/whill_common_matlab-main _ndtDebug`）：`acsl-tcu/whill_common_matlab` のフォーク `MaeharaTakumi/whill_common_matlab`
  （`origin` がフォーク、`upstream` が元）のブランチ `cr_debug`。フォルダ名に空白があるので `repos.yaml` には入れていない。
  CRLF・実行権付きの .m があるので、このフォルダの `.git` だけ `core.fileMode false` と `.git/info/attributes` の `* -text`。
  ホストの MATLAB R2026a（ROS Toolbox）は `-batch` で動かせる（MATLAB の MCP はつながらないことがある）。
- `robot_localization` ブランチ（localization_bringup の 23767ee）は廃止した robot_localization の版（`dev_log.md` の 1〜23）。

## コンテナ

| コンテナ | イメージ | 役割 |
|---|---|---|
| `20261002`（8843520b410f） | `ubuntu_22_04` | Gazebo（車椅子モデル・ワールド・MATLAB 連携）。**編集禁止**（許可済みの変更は `gazebo_changes.md`） |
| `test` | `localizer_maehara:latest` | **自己位置推定の開発用**（`docker/` からビルド。compose のプロジェクト `localizer_maehara`） |

- `ros2_0605`・`ros2_1024`・`ros2_v2`・`gazebo_zireiken2026` は自己位置推定とは別のコンテナ（触らない）。
- 自己位置推定のコンテナは同じ ROS_DOMAIN_ID・host network なので、同時に推定を動かすのは 1 つだけ。
- `test` の通信設定（`.bashrc`）は既定で Gazebo 用：`ROS_DOMAIN_ID=11`、Fast DDS のプロファイル `/root/fastdds_localhost.xml`（127.0.0.1 の UDP だけ）。
  実機（LAN 越しに LiDAR PC と通信）では `.bashrc` の通信設定ブロックを切り替える。
- **Gazebo の通信**：`20261002` の `.bashrc` で Gazebo 自体の探索を lo に限った（`gazebo_changes.md`）。ただし Gazebo の master の TCP 11345 などは
  0.0.0.0 で待ち受ける（閉じるにはホストのファイアウォール。ユーザーが行う）。
- **録画・地図・図はホストの `docker/data/{bags,map,fig}` を割り当てたもの**（コンテナを作り直しても消えない。中で作ったファイルは root の持ち物）。
  地図 `SC10_4_0.05.pcd`（Gazebo の建物）と `10build_4F_C_20260414.pcd`（実機 blue の録画）は `data/map` にある。
- ホストの `net.core.rmem_max`・`rmem_default` は 8 MB 以上にする（実機の点群 314 kB が受信バッファ 208 kB からあふれ、再生で約半分落ちる。
  `sysctl -w` なので再起動で戻る。sudo は Claude Code の中から動かないのでユーザーが行う。`dev_log.md` の 66・67）。
- NVIDIA ドライバの自動更新で `docker start` が「libnvidia-egl-wayland.so.1.1.17: no such file」と止まったら、ホストに古い名前から新しい版への
  リンクを作る（sudo が要るのでユーザーが行う。2026-10-15 に 1.1.17 → 1.1.21 で起きた）。

### イメージとコンテナを作り直す

`docker/` で `docker compose build`（各リポジトリは GitHub の最新を取り込む）→ `docker compose up -d --force-recreate`。そのあと：
`./deploy.sh`（`src/` を写してビルド、localization_tools を `sync.sh push`）、`.bash_history`・`.rviz2`・`.ssh/known_hosts`・`.gitconfig` を戻す
（VS Code の `.vscode-server` は戻さない）、ekf_localizer のテストが通ること、**ROS 2 が Gazebo 用（DDS のソケットは送信用も含めて 127.0.0.1 の
UDP だけ、TCP なし、LAN で 239.255.0.1 に参加しない）であること**を確かめる（ユーザー指示）。

イメージの中身：`ros2_ws/src` に GitHub の 5 つ（`lidarslam_ros2`・`lidar_localization`・`whill_odometry`・`ekf_localizer`・`localization_bringup`。
build-arg `BRINGUP_BRANCH` で bringup だけ別のブランチにできる）、`/root/ros2_ws/localization_tools`、`/root/ros2_ws/{map,bags/{gazebo,real},fig}`
（`COLCON_IGNORE` 入り）、`/root/.bash_aliases`（`docker/src/aliases.txt`）、`/root/ros2_ws/README.md`（`docker/README.md`）。

コマンド（`.bash_aliases`）：`localization [red|blue|white|gazebo] [地図]`（既定 red。地図は名前でもパスでもよく、省くと選ぶ画面）、
`lidarslam [red|blue|white|gazebo]`（SLAM。既定 red）・`savemap`（`lidarslam` と同じディレクトリで実行）、
`ekf_params`・`lclz_params`・`odom_params`・`slam_params [色]`（`param/<色>/` のノードの yaml を開く）、
`scanmatch_cli <地図> [env]`、`drive`・`drive_list`・`bags_list`、`calibration`・`calibrate`・`calibration_plan`・`calibration_params`。

## よく使うコマンド

コンテナ内の ROS 環境は `~/.bashrc` で読み込まれるので、`docker exec` では `bash -ic` を使う。

```bash
./deploy.sh                                # src/ の 5 つを写してビルド + localization_tools を sync.sh push（ホストで実行）
./deploy.sh --test ekf_localizer           # ビルドとテスト（gtest：test_ekf_models・test_lagged_ekf・test_tf_grid）
./deploy.sh --mirror localization_bringup  # コンテナ側を消してから写す（消した・名前を変えたファイルを残さない）

# Gazebo の起動（20261002 の履歴と同じ。ファイルは編集しない）。止めるときは pkill -INT -f "ros2 launch connection_wheelchair"
docker exec -d 20261002 bash -ic 'ros2 launch connection_wheelchair connection_wheelchair.launch.py > /tmp/claude_gazebo_launch.log 2>&1'

# 自己位置推定の起動（コンテナの中）。引数：env（gazebo・red・blue・white かフォルダのパス）、use_ekf、map_path、rviz、matcher（ndt・lidarslam）
ros2 launch localization_bringup localization.launch.py env:=gazebo
ros2 launch localization_bringup localization.launch.py env:=blue map_path:=/root/ros2_ws/map/<地図>.pcd
ros2 launch localization_bringup lidarslam.launch.py env:=blue      # SLAM（matcher:=lidarslam で localization.launch.py を読むだけ）
```

- **`docker exec ... bash -ic` の中で `ros2 launch ... &` とバックグラウンドで起動しない。** SIGINT が無視されてノードが残る（同じ名前のノードが
  2 組になり、推定が壊れたように見える。`setsid` でも直らない）。長く動かすものは `docker exec -d ... bash -ic '<コマンド>'` で起動して
  `pkill -INT -f` で止めるか、フォアグラウンドで `timeout -s INT` にする。止めたら `ps` で確かめる。rviz2 は SIGINT で終わらないことがあるので SIGKILL。
- **`timeout` の中で `ros2 topic` などを使うときは `--no-daemon --spin-time 3` を付ける**（そこで初めて CLI のデーモンが起動すると時間切れのシグナルで
  壊れ、以後の `ros2 topic` が `!rclpy.ok()` で落ちる。直すには `ros2 daemon stop`。`ros2 topic hz` は `--no-daemon` を受け付けない）。
- sudo は Claude Code の中のシェルからは動かない（no new privileges）。

## localization_tools

**検証・調整・描画・テスト走行・パラメータ推定のプログラム**（ユーザー指示で残す）。編集はホスト、**実行は `test` の `/root/ros2_ws/localization_tools`**
（`./sync.sh push` で写す。`./sync.sh pull` でコンテナの結果 `eval/results/*.jsonl` と図 `/root/ros2_ws/fig` をホストの `results/` へ）。
使い方は `localization_tools/README.md`。

| フォルダ | 中身 |
|---|---|
| `common/` | 共通部品：`env_files.py`（localization_bringup の環境のフォルダを読む・写して書き換える）、`bag_io.py`（bag の読み込み・`phases_of`・stamp の変換・`/tf_static` からの取付）、`pose_math.py`、`plot_style.py`（色・書式・`capitalize_labels`・`box_on`）、`gazebo_model.py`（Gazebo の車輪・倍率・URDF の取付）。各スクリプトは `common`・`plot`・`eval`・`calibration` を `sys.path` に入れて import する（`/tmp` には依存しない） |
| `drive/` | テスト走行と録画（Gazebo・実機共通） |
| `calibration/` | パラメータ推定（プログラムと設定 `param/`） |
| `eval/` | 再生・評価・調整（候補 `batches/`、結果 `results/`） |
| `plot/` | 図。`rerender_results.sh` で `results/` の図を全部描き直す |
| `matlab/` | MATLAB の確認（`replay_matlab.sh` はホストで実行） |
| `record_rviz.sh` | RViz の画面の録画（ホストで実行、ffmpeg の x11grab） |

### テスト走行と録画（`drive/`）

- `drive/run_test.sh <gazebo|red|blue|white> <動き> [<bag 名> [launch の追加引数]]`（コマンド `drive`）。bag 名を省くと `<target>_<動き>_<日時>`、
  `check/<名前>` にすると `bags/<source>/check/`（ツールの動作確認。比較・調整には使わない）。ホストからでもコンテナの中からでも実行できる
  （docker が無ければコンテナの中とみなす。実機の PC ではコンテナの中から。ホストからでも動くのはコンテナのツールで、
  ツールを写すのは `deploy.sh`・`sync.sh push` だけ。実行するスクリプトは写さない）。Gazebo はホストからなら起動し直して推定器も起動、
  コンテナの中からは起動し直さない。実機は推定・whill_driver・LiDAR を起動しない。走る前の確認（取付の TF が引ける・姿勢が届く・指令を受けるノード（録画は数えない）がある・録画する
  トピックがあるか）は、録画を始めた後に `drive_test.py` が 1 つのノードで行う（欠けたら走らずに止める。`ros2` の CLI は使わない。`dev_log.md` の 89）。
- 動きは `drive/profiles.yaml`（spin・spin5・stops・accel・curve・slalom・reverse。速さは上限に対する割合）、設定は `drive/config/<target>.yaml`
  （上限：Gazebo v 1.5・後退 0.8 m/s・ω 1.0 rad/s、実機 0.5・0.3・0.5）。実機の姿勢 `/ekf_pose`（LiDAR）は、取付を設定に書かず TF から引いて車体に直す
  （`feedback` の `lidar: true`。フレームは `param/<target>/ekf_localizer.yaml`。`dev_log.md` の 91）。`CONFIG=real_in_gazebo` で実機の設定を Gazebo で試す。
  `CONFIG=gazebo_ground`（動きは `PROFILES=.../drive/profiles_velocity.yaml`）は車椅子を世界の原点の地面に置き、推定を起動しない（`dev_log.md` の 57）。
- 走る前に計画（計算した軌跡）を表示する。実機は Enter で走り出す（何か入力して Enter なら取りやめ）。走ってよい範囲の確認はしない（`dev_log.md` の 77）。
  走行中は姿勢が 0.5 s 来ない（壁時計）・ジョイスティック・時計の停止・区間 60 s・Ctrl-C/SIGTERM で 0 を送って止める（rclpy に Ctrl-C を処理させない）。
- 録画は `/root/ros2_ws/bags/<gazebo|real>/<bag 名>` と `_phases.txt`（動作の開始時刻）・`_drive.log`・`_info.yaml`（`eval/bag_info.py`。途中で止めたら理由も）。
  一覧は `bags_list [gazebo|real]`。2026-10-13 より前の Gazebo の録画は旧版の動き（大きさが違う）。

### パラメータ推定（`calibration/`）

- `calibration/run_calibration.sh <target> [<bag 名>]`（コマンド `calibration`）：推定用の動き（`param/motion.yaml` の 5 つ：その場で左に 4 周 → 止まる 5 s →
  片道の直進 → 止まる。Gazebo・実機共通。drive の動きとは別。`calibration/motion.py` が作り `PROFILES` で `run_test.sh` に渡す）で走って録画し、
  `calibration/calibrate.py <target> <bag>`（コマンド `calibrate`）で R（R_odom・R_ndt）・倍率・取付を推定する（Gazebo は真値との比較 `--truth` も）。設定は `param/calibrate.yaml`
  （各プログラムのオプションの既定値。`params.py` が読む）。結果は `/root/ros2_ws/fig/calibration/<bag 名>/summary.yaml`（env には書き込まない）。
- `calibrate_noise.py`：**観測ノイズ R を真値なしで求める**（指令が一定の区間の局所 1 次式の残差の分散 × 積分相関時間）。R_v は定速の直進の v の残差、
  **R_omega = 4 R_v (s_omega/s_v)² / b²**（左右の車輪のノイズが独立と仮定。b は Gazebo 0.492（`noise.gazebo_tread`）、実機は whill_odometry の `tread_width`）。
  R_ndt も走行中の残差から求める。残差のヒストグラム `_hist.png`（縦軸 `Relative frequency`、黒で縁取り、NDT の 6 つは範囲をそろえる、頑健な σ（1.4826 MAD）の
  正規分布 1 本）。`--truth` は Gazebo だけの検算。
- NDT の R を「真値 + ノイズ」の初期値で求める `calibrate_ndt_noise.py`（Gazebo）は 2026-11-13 に消した（git の履歴にある。`dev_log.md` の 15・49・90）。
- `calibrate_mount_scale.py`：**LiDAR の取付（x, y, yaw。roll・pitch・z は参考）とオドメトリの倍率を真値なしで推定**。取付の yaw は直進の区間で
  LiDAR の yaw − 車体の進む向きを各時刻で求め、RANSAC（0.3° 以内のインライアが最多）で平均する（`dev_log.md` の 49〜52）。
  **取付の roll・pitch・yaw は表示・`summary.yaml`・図とも rad**（`env.yaml` の `static_tfs` と同じ）。

### 再生と評価（`eval/`）

- 再生は `ROS_DOMAIN_ID=99`（動いている推定・Gazebo・MATLAB と混ざらない）。起動・録画・再生・停止の流れは `tune_run.launch_and_play` の 1 つ。
  出力は入力と同じ側の `bags/<source>/tune/<試行名>`（試行名に `/` は使えない）。ノードが再生の途中で落ちた回はエラーにする。
- `eval/tune_run.py <bag> <試行名> '<parameters の JSON>' ['use_ekf:=false']`：Gazebo の録画を左回転の 8 秒前から再生し、指標（回転中の yaw 誤差・
  angle_diff・xy 誤差・4 つの瞬間の跳ね。`transition_eval.py`）を 1 行 JSON で出す。JSON は `{ノード名: {パラメータ: 値}}`（写した `param/gazebo/` の `<ノード名>.yaml` に上書き。`common/env_files.py`）、`"__env__"` は `env.yaml` を上書き。
  `tune_batch.py`（候補 `batches/`、結果 `results/`）、`aggregate.py`（候補ごとの平均と幅。`SHOW_RUNS=1` で 1 回ごと）。
- `eval/replay_outputs.py <bag> <試行名> [<env> <地図>]`：録画全体を再生して `/tf` などを録る（実機は env と地図も）。`PARAMS`（JSON）でパラメータを上書き、
  `RECORD=0` で録らない、`RATE` で速さ。図は `plot/plot_matlab_outputs.py`（`compare` で比べる）、まとめて流すのは `outputs_batch.py`。
- `eval/compare_run.py`：推定器の比較（6 軸の誤差、実時間の誤差、切り替え時の yaw、推定の古さ。図は `plot/plot_motion_compare.py`）。
- **同じ設定でもスコアは ±0.05 程度ばらつく。R が小さいと振動に入るかどうかで大きく変わるので、4 回以上流して 1 回ごとの値も見て、
  良い設定は調整に使っていない録画で確かめる。**
- 録画の置き場所（`eval/bag_paths.py`）：`/root/ros2_ws/bags/gazebo/<名前>`・`/root/ros2_ws/bags/real/<名前>`、再生の出力は各 `tune/`。
  Gazebo のオドメトリの移動平均を 1 にした（2026-10-12）**より前の録画は 0.2 s の移動平均で約 0.1 s 遅れている**。移動平均 1 の録画は
  `spin360_w1_ekf`（調整用）と `spin360_w1_ekf2`（確認用）。実機 blue の `blue_calibration_20261016_133648`・`134316` はラズパイの時計がずれていて
  時刻を `stamp` にしたままでは再生できない（`141128` 以降は正常。`dev_log.md` の 76）。

## グラフの作り方（ユーザー指示）

- 折れ線は、後方（先に描く・zorder が低い）の線ほど太く描く。真値は一番後ろの太い薄灰色の実線（`common/plot_style.py` の `TRUTH_COLOR`・`TRUTH_LW`・
  `widths_back_to_front()`）。凡例の線幅もそろえる。
- 点線・破線はできるだけ使わない。系列の区別は色と太さで。色は dataviz の参照パレットから選び、`validate_palette.js` で検証する。
- **図の枠は 4 辺とも黒**（MATLAB の box on。`plot_style.box_on`、`style(ax)` の既定）。
- **題・軸ラベル・凡例・注記の頭文字は大文字**。保存の直前に `plot_style.capitalize_labels(fig)`（先頭の語が `ekf_localizer` などの識別子ならそのまま
  なので、凡例・題は `EKF (ekf_localizer)` のように大文字の語から始める）。
- 描画は `test` の `/root/ros2_ws/localization_tools` で実行し、図は `results/` に置く。開発ログに埋め込む図は `dev_log_images/` に写す。
  ツールを直したら、`plot/rerender_results.sh` を `OUT=<別の場所>` で変更前・変更後に流し、図をファイルごとに比べる（`dev_log.md` の 83）。

## アーキテクチャ（NDT + EKF）

詳細は `localization_bringup/docs/node_graph.md`（ノード・トピック・QoS・TF 表）と `ekf_localizer/docs/ekf_flow.md`。

```
点群 ─▶ pcl_localization (NDT) ─▶ /ndt_pose ─▶ ekf_localizer ◀─ /wheelchair/odom ◀─ whill_odometry（実機）・Gazebo
        （SLAM のときは scan_matcher ─▶ /slam_pose。/map_array ─▶ graph_based_slam）
              ▲                                      │  （倍率 odom_scale・時刻 odom_stamp_mode は EKF）
              └── TF map→LiDAR（点群の時刻）◀────────┘ /tf map→base（50 Hz）, /ekf_pose, /ekf_odom
```

- **設定（`localization_bringup/param/<env>/`。2026-11-11 から、`dev_log.md` の 84）**：`env:=<名前>`（フォルダのパスでもよい）。
  - `env.yaml`（launch が読む）：`use_sim_time`、`nodes`（`whill_odometry`・`pcl_localization`・`ekf_localizer`・`rviz` を true / false）、`static_tfs`。
    launch 引数 `use_ekf:=`・`rviz:=` が優先。**env を付けないと NDT と EKF だけを、yaml を渡さずコードの既定値で起動する**（取付・地図・sim time が無いので推定には使えない）。
  - `<ノード名>.yaml`（`ekf_localizer`・`pcl_localization`・`whill_odometry`）：普通の ROS のパラメータファイル。全項目を書く（無い項目はコードの既定値）。
  - launch が入れるのは `use_sim_time`、NDT・scan_matcher の `publish_tf`（いつも false）・`use_tf_init_guess`（EKF を起動するときは true）、`map_path`（引数を付けたとき）だけ。
    yaml を読んで重ね、**ノード名の節の一時 yaml**（`_scoped`、整数と小数が混ざった数のリストは小数にそろえる）で渡す。一時 yaml は `/tmp/localization_bringup_*/`。
    起動ログに各ノードが読んだ yaml（無ければ `code defaults`）が出る。効いた値は `ros2 param dump /<ノード名>` で確かめる。
  - トピックは各ノードの名前のままでつながる。launch が付け替えるのは ekf_localizer の `odom` → `/wheelchair/odom` と NDT の `pcl_pose` → `/current_pose`
    （RViz と、研究室の MATLAB（whill_common_matlab の CR）の実機モードが購読する名前）、SLAM のときの scan_matcher の `input_cloud` → `/velodyne_points` と
    ekf_localizer の `ndt_pose` → `/slam_pose`、`pose_to_tf` の `pose` だけ。
  - **TF は EKF が出す**。NDT・scan_matcher には launch がいつも `publish_tf: false`、`use_tf_init_guess` = EKF を起動するか、を入れる。
    **EKF を起動しないときは `pose_to_tf`**（bringup の `scripts/pose_to_tf.py`）が解（map → LiDAR）に取付の逆を掛けて map → base を解の stamp で出す
    （フレームは `ekf_localizer.yaml` の値。2026-11-12 から。それまでは NDT が自分で出していた。`dev_log.md` の 85）。
- **SLAM（`lidarslam.launch.py`、コマンド `lidarslam`。2026-11-12、`dev_log.md` の 85）**：`matcher:=lidarslam` で pcl_localization の代わりに lidarslam_ros2 の
  scan_matcher（逐次の位置合わせと地図作り）と graph_based_slam（ループ閉じ込み、savemap のサービス `/map_save`）を起動する。環境は NDT と同じ
  `param/<env>/`、SLAM のパラメータは `lidarslam.yaml`（初期姿勢は `pcl_localization.yaml` と同じ値）。scan_matcher への変更は最小限：
  `use_tf_init_guess`・`tf_init_guess_timeout`（NDT と同じ名前・既定値。点群の時刻の map → `robot_frame_id` を TF から引く）と、NDT の `/ndt_pose` と同じ型・QoS の
  `/slam_pose`。`robot_frame_id: velodyne` で解を LiDAR の姿勢にする（点群は変換しない）。EKF は `/slam_pose` を NDT の解と同じに扱う（`R_ndt` も同じ）。
  graph_based_slam で直した姿勢は scan_matcher・EKF には戻らない（直るのは保存する地図だけ）。RViz は lidarslam の `mapping.rviz`。
  `/current_pose` は scan_matcher のもとの PoseStamped（MATLAB CR の sensor 4 の型）。
  - 古い形（`param/env/<名前>.yaml`、`odom_relay`・`odom_covariance`・`joint_state_odometry`、env の `topics`・`parameters`・`stamp_mode`）はやめた。
- **時刻**（`stamp`・`receipt`・`auto`。auto は |受け取った時刻 − stamp| が閾値以上なら受け取った時刻）：点群は NDT の `stamp_mode`・`stamp_auto_threshold`
  （`/ndt_pose` の stamp と初期値の TF を引く時刻。点群のトピック自体の stamp は変えない。EKF は `/ndt_pose` の stamp を使う。`/ndt_pose` の受信時刻は
  NDT の計算の遅れを含むので使わない（ユーザー指示。`dev_log.md` の 20））、オドメトリは ekf_localizer の `odom_stamp_mode`・`odom_stamp_auto_threshold`
  （EKF が受け取った時刻）。sim time で `/clock` を受け取る前は stamp のまま。今は実機・Gazebo とも `stamp`。
- **NDT（SLAM では scan_matcher）と EKF は TF で循環している**：`use_ekf:=true` のとき NDT は `use_tf_init_guess: true` で、**点群の stamp** の map→LiDAR を
  TF から引いて初期値にする（`tf_init_guess_timeout` 0.05 s。引けないとき（EKF の初期化前、`/initialpose` から 1 秒間）は前回の解）。
- **`/ndt_pose`**：map→**LiDAR**、stamp は点群の取得時刻、共分散は未設定（0）。**`/initialpose`** も NDT は LiDAR の姿勢として扱う（RViz の 2D Pose Estimate は z=0）。
  NDT の `/path` は配信しない（ソースでコメントアウト。`dev_log.md` の 83）。
- **`/tf`・`/ekf_pose` の出し方**：ekf_localizer は `predict_rate`（50 Hz）の周期で、最新の状態を現在時刻まで予測した TF map → base・`/ekf_pose`
  （map→**LiDAR**、reliable + transient_local、KeepLast(1)）・`/ekf_odom`（v_xy・omega_yaw だけ）を出す。`tf_future_steps`（F）が 1 以上なら `/tf` の stamp を
  周期の刻み k·T（整数 ns）にそろえ、k0 − `tf_past_steps` + 1 〜 k0 + F の刻みを毎周期 1 メッセージで送り直す（tf2・MATLAB の `ros2tf` は同じ stamp を
  後の値で置き換える）。**環境ファイルは 4 つとも F = 2・P = 1**（点群が届いた時点で TF が揃っていない割合が 0 %。P ≥ 2 だと引く値が引く時刻で変わる。`dev_log.md` の 72）。
- **RViz** は `/tf` をそのまま読む（点群はその stamp の予測値の補間、視点の Target Frame `base_link` は最新の値。既定の視点は `TopDownOrtho`）。
  RViz2 は設定ファイルの `Hide Left Dock` などを起動時に効かせない（`dev_log.md` の 53〜57・69・70）。
- **MATLAB**（CR_debug）：sensor(1) で `/velodyne_points` を購読し、`ros2tf`（既定 10 s 溜める）から、sensor(5)（Matching）は最新の map → base を `Plant` に、
  点群の stamp の map → velodyne（事前推定値。NDT の初期値と同じ値）を `data.LIDAR_pose` に入れる。点群の stamp の TF が引けないか、今の時刻と点群の
  stamp の差が `lidarStampThreshold`（既定 0.1 s）以上なら最新の TF と組にする（`data.LIDAR_latest_tf`）。TF が 1 つも引けないときだけ前の組のまま。
  sensor(4)（実機の `/ekf_pose`）はやめた（true にするとエラー）。図は `+plotter/myplotResult.m`、動画は `+plotter/myplotPointCloudVideo.m`、
  再生から図・動画までは localization_tools の `matlab/replay_matlab.sh`（`dev_log.md` の 61〜68・75・78・79）。
- **ekf_localizer**（`src/ekf_core.cpp` など）：
  - 状態は 11 個 `[x, y, z, roll, pitch, yaw, v_xy, v_z, omega_roll, omega_pitch, omega_yaw]`（添字 `kVxy`・`kVz`・`kOmegaRoll`・`kOmegaPitch`・`kOmegaYaw`、
    取り出しは `vXy()`・`omegaYaw()`）。`Q`・`P_init` も 11 要素（8 要素だと WARN を出して既定値）。
  - 予測は各軸独立：水平面を移動すると仮定した中点法（yaw_m = yaw + omega_yaw dt/2、x += v_xy dt cos(yaw_m) …）、z・roll・pitch は v_z・omega_roll・
    omega_pitch で線形に積分。速度 5 つはランダムウォーク。v_z・omega_roll・omega_pitch の `Q`・`P_init` が 0 ならその 3 つは 0 のまま（8 状態と同じ）。
  - **NDT の観測**（`src/ndt_model.cpp`）：LiDAR の姿勢を取付で base の姿勢 T_L·T_BL⁻¹ に直し、`R_ndt`（LiDAR、対角）をヤコビアンで伝播した相関込みの
    6×6 で 6 成分を 1 回で更新する。ゲートは `gate_ndt`（既定 1e5 で実質無効。観測モデルの構造体の既定 16.81 はテスト用）。`/ekf_pose` の共分散は `lidarPoseJacobian`。
  - **オドメトリの観測**：`R_v = R0 + a0·v² + a1·ω² + (τ0·dv/dt)²`、`R_ω = R0 + a2·v² + a3·ω² + (τ1·dω/dt)²`（`OdomNoise`。`R_odom`・
    `odom_noise_alpha`・`accel_noise_tau`）。v・omega には先に `odom_scale` を掛ける。メッセージの共分散は使わない。遅れの補正は `odom_delay`・`ndt_delay`（stamp から引く）。
  - NDT の観測の時刻はメッセージの stamp、オドメトリは `odom_stamp_mode`。遅れて届く NDT は `LaggedEkf` が巻き戻して入れ直す（`history_length` 1 s）。
  - トピックは `ndt_pose`・`odom`・`initialpose`（変えるときは remap。`*_topic` パラメータは 2026-11-11 にやめた）。
  - **ノイズの既定値（コード。`param/<env>/ekf_localizer.yaml` にも全項目）は実機 blue の値**：Q `[0.05, 0.05, 0.005, 0.05, 0.05, 0.05, 0.05, 0, 0.1, 0.1, 10]`、P_init `[0.2, 0.2, 0.2, 0.01, 0.01, 0.01, 0.01, 0, 0.01, 0.01, 0.01]`、
    R_ndt `[2.08e-4, 1.55e-4, 9.61e-5, 5.89e-5, 6.32e-5, 1.23e-5]`、R_odom `[6.08e-3, 9.92e-4]`、alpha・tau 0（`dev_log.md` の 76・80・82）。
    コードの既定と環境で違うのは `tf_future_steps`・`tf_past_steps`（コード 0・0、環境 2・1）、`odom_scale`（コード [1, 1]）、Gazebo の `base_frame_id`。
    ノイズは red・white・blue がこの値、Gazebo は Q の速度 3 つを 0 にしている（P_init・R_ndt は既定のまま。
    82 の再生で Gazebo は悪くなった）。実機の omega_roll・omega_pitch 0.1 の改善が傾きの動きか NDT の誤差を追っただけかは、真値が無いので分からない。
- **オドメトリ**：使うのは `twist.linear.x`・`twist.angular.z`。Gazebo は diff_drive_controller の odom を `gazebo_bridge` が中継する `/wheelchair/odom`
  （50 Hz、best effort、共分散 0、移動平均 1）、実機は `whill_odometry`（共分散 0）。ekf_localizer が `/wheelchair/odom` を直接購読し、倍率 `odom_scale`
  [v, omega]（`ekf_localizer.yaml`）を掛ける。倍率は Gazebo [1, 0.922]（実効的な車輪間隔が設定より約 8 % 広い）、
  blue [1.014, 1.0141]、red・white [1, 1]（未校正）。
- **取付 TF**：実機は launch が `env.yaml` の `static_tfs` を配信し、Gazebo は URDF（Gazebo 側の robot_state_publisher：`base_footprint→base_link`（z 0.10）
  `→velodyne_base_link`（-0.17, 0, 1）`→velodyne`（z 0.0377））を使う（`param/gazebo/env.yaml` の `static_tfs` は空。launch からも配信すると親が 2 つになり、ノードごとに
  違う取付を読む）。基準フレームは Gazebo `base_footprint`、実機 `base_link`。各ノードの起動ログの `mount ... (from TF)` で確かめられる。
- **angle_diff**（`/localization_debug` の data[4]）は、初期値と NDT の解の**それぞれの回転の大きさ**の差。2 つの姿勢の間の角度ではないので、yaw が 0 や ±π の付近では小さく出る。
- 再生を止めるときに ekf_localizer がまれにセグメンテーション違反（exit code -11）で落ちる（止めた後なので結果には影響しない）。

## 実機（ラズパイは `acsl-tcu/project_whill`）

- 車椅子（WHILL CR）と LiDAR（VLP-16）はラズパイ（ホスト名 `Drp5_whill_<色>`）の project_whill が動かす（cyclonedds）。**車椅子は blue・red・white の 3 台**。
  色は自己位置推定の `env:=<色>`（`param/<色>/`。red と white は `whill_odometry.yaml` の `input_topic_name` だけが違い、blue は取付と倍率も違う）と
  `run_test.sh <色>`（`drive/config/<色>.yaml`）で選ぶ（両方を同じ色にする）。
- 自己位置推定の PC と LiDAR の PC は時刻同期している（NDT の `stamp_mode`・EKF の `odom_stamp_mode` とも `stamp`）。whill_odometry は `use_stamped_input: true` でラズパイの stamp を使う。
  `auto` を使う前は、ログ（10 s ごとの「receipt time used for …」）で実機のずれを確かめる。
- whill_driver（名前空間 `/<ホスト名>/whill_node`）：`~/cmd_vel` を受ける（1 s 途切れると止まり、ジョイスティックが倒れていると無視。上限は前進 1.67 m/s、
  後退 0.56 m/s、旋回約 0.83 rad/s）。`~/motor_speed_ts`（左右輪の速度 km/h、x = 右・y = 左）などを 50 Hz で出す。
  whill_odometry：v = (v_left + v_right)/2、omega = (v_right − v_left)/`tread_width`（0.495 m、未確認）。
- velodyne は 20 Hz、`/velodyne_points`。RTK-GNSS は MATLAB が `/ublox_gps_node/fix` を使う（録画しない）。
- 録画するのは点群・`motor_speed_ts`・`cmd_vel`・バッテリーと推定の出力（`motor_angle_ts`・`joy_ts`・`speed_mode`・GNSS は録らない。`joy_ts` は走行中の監視に使う）。
- NDT の解は実機 blue の走行中で点群が届いてから平均 34 ms（50 ms 以内 99.4 %）、Gazebo で平均 37〜43 ms。

## Gazebo の性質と評価の注意

- Gazebo の評価は `/ekf_pose`（LiDAR）を主に見る。真値 `/wheelchair/pose` は header が無いので bag の受信時刻を `/clock` で直して使う。
- 地図と Gazebo の座標の間に xy 約 4.5 cm のずれがあり（止まっていても同じ。開始位置 x +41・y −21 mm、直進 16 m 先で x 0 mm と場所で変わる）、
  どの推定器でも出るので、長く走る録画の xy は推定器どうしの差で見る。
- Gazebo のオドメトリ：回転中の omega は真値の 1.08〜1.09 倍（実効的な車輪間隔 0.532〜0.535 m）、直進の v は一致。地面（ground_plane）では
  0.901〜0.907 と床で違う（理由は未調査。`dev_log.md` の 57）。停止の瞬間に車体がブレーキで向きを変えるのはオドメトリに出ない（`dev_log.md` の 9〜12）。
- 小さい R_ndt（真値なしで求めた値、blue の値）にすると、Gazebo では EKF が遅れて届く NDT に飛びつき、NDT が真値の近くの別の解に収束するのに
  引っ張られて振動に入りやすい（`dev_log.md` の 13〜17・82）。
- Gazebo の録画には 1〜3 ms 違いの点群の組がある（1 周の録画で 12 組）。
- 未確認：実機の omega の倍率（red・white）、whill_odometry の `tread_width`、実機のオドメトリの遅れ。
