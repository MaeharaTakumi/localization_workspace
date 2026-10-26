# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## このディレクトリの役割

`Docker/localization/` はホスト側の作業場所（自己位置推定）。開発対象のリポジトリを `src/` に clone して編集し、`docker cp` で
自己位置推定コンテナ `test` に反映して、ビルド・実行はコンテナ内で行う。
2026-10-23 にユーザー指示で `Docker/workspace` から構成を変えた（今後 localization 以外の Docker も `Docker/<名前>/` に同じ形で並べる）：

| 場所 | 中身 | git |
|---|---|---|
| `./`（このディレクトリ） | `CLAUDE.md`・`dev_log.md`・`gazebo_changes.md`・`dev_log_images/`・`repos.yaml`・`clone_repos.sh` | **`MaeharaTakumi/localization_workspace`（Public、main）**。`.gitignore` で `src/`・`docker/`・`archive/`・`results/`・地図・動画を外す |
| `src/` | 開発中のリポジトリ（下の 6 つ）と MATLAB（`whill_common_matlab-main _ndtDebug`） | それぞれ単独のリポジトリ（一覧は `repos.yaml`、`./clone_repos.sh` で clone）。MATLAB は `MaeharaTakumi/whill_common_matlab`（Public）の `cr_debug` ブランチ（下記。フォルダ名に空白があるので `repos.yaml` には入れていない） |
| `docker/` | Docker 定義（`MaeharaTakumi/localizer_docker`）と `data/{bags,map,fig}`（録画・地図・図。git の外） | 単独のリポジトリ |
| `results/` | 描いた図すべて（`sync.sh pull` の行き先。git の外） | なし |
| `dev_log_images/` | 開発ログ・`gazebo_changes.md` に埋め込む図（`results/` から写す。**開発ログに図を足したら、ここに写して埋め込む**） | このリポジトリ |
| `archive/` | 使っていないもの（`localizer_ekf_docker` など） | なし |

push はリポジトリごとに、作業の区切りのよいところで行う（このリポジトリも）。

- **MATLAB**（`src/whill_common_matlab-main _ndtDebug`。2026-10-26、ユーザー指示）：`acsl-tcu/whill_common_matlab`（Public）を
  `MaeharaTakumi/whill_common_matlab` にフォークし、手元のフォルダをその場で git にした（ファイルは動かしていない。`origin` がフォーク、`upstream` が元）。
  ブランチ `cr_debug`（フォークの main は元のまま）は、元の `4cae255`（2026-03-31。手元のフォルダの元）に、今の CR_debug（`b7ef33f`）と
  MATLAB 用の出力の購読（`4db08f7`）を足したもの。元の main のその後の 2 つ（MATLAB 2026a 対応の `+mode/+CR/GazeboMode.m`、README）は
  取り込んでいない（手元で変えていないファイルなので衝突しない）。手元の .m は実行権付きで CRLF のものもあるので、このフォルダの `.git` だけで
  `core.fileMode false` と `.git/info/attributes` の `* -text`（改行を直さない）にしている。`data/` は元の `.gitignore` で外れる。
  ホストの MATLAB R2026a（ROS Toolbox）は `-batch` で動かせる（MATLAB の MCP はつながらないことがある）。
ROS 2 Humble / Ubuntu 22.04。ホストに ROS は無いので、ビルド・テスト・起動はすべて `docker exec` 経由。

- `src/localization_bringup/`：`MaeharaTakumi/localization_bringup` の clone。ブランチ `humble`（2026-10-15 に `robot_localization` ブランチから
  robot_localization を外して humble にマージした。以後 humble で開発。`robot_localization` ブランチは廃止前の 23767ee のまま残す）
- `src/lidar_localization/`（NDT・`cloud_stamp_corrector`）・`whill_odometry/`：`MaeharaTakumi/*` の clone（ブランチ `humble`。2026-10-15 から）。
  反映は `docker cp src/<リポジトリ>/. test:/root/ros2_ws/src/<リポジトリ>/` と chown、ビルド（パッケージ名は `pcl_localization_ros2`・`whill_odometry`）
- `src/ekf_localizer/`：`MaeharaTakumi/ekf_localizer` の clone（ブランチ `humble`）。2026-10-12 にユーザー指示で予測を中点法に（b2360c0）、
  NDT の観測を base の姿勢に（be6fce8）変更（GitHub の humble に push 済み）。反映は `docker cp src/ekf_localizer/. test:/root/ros2_ws/src/ekf_localizer/` と chown、ビルド
- `dev_log.md`：**開発ログ（グラフ付き）。作業したら日付・項目ごとに末尾へ追記する（ユーザー指示）**。各項目は
  目的・やったこと・結果（数値）・図（`dev_log_images/` の png を埋め込む。`results/` から写す）。説明は簡潔に
- `src/localization_tools/`：**検証・調整・描画・テスト走行のプログラム（ユーザー指示で残す。GitHub `MaeharaTakumi/localization_tools`、Public。ブランチ main。2026-10-14 から）**。
  編集はホスト、**実行は自己位置推定コンテナ `test` の `/root/ros2_ws/localization_tools`**（2026-10-14 にユーザー指示で `/root/localization_tools` から移した。
  ROS のパッケージではないので src の外、`COLCON_IGNORE` 入り）（`./sync.sh push` で写す。
  `./sync.sh pull` でコンテナの結果 `eval/results/*.jsonl` と図 `/root/ros2_ws/fig` をホストへ）。使い方は `localization_tools/README.md`。
  スクリプトは `plot/`・`eval/`・`calibration/` を sys.path に入れて互いに import する（`/tmp` には依存しない）
  - **パラメータ推定は `calibration/` にプログラムとパラメータをまとめる**（2026-10-15、ユーザー指示。それまでの `noise/`・`calib/`・`param/`）。
    設定は `calibration/param/motion.yaml`（推定用の動き。**推定の動きは 1 つで drive の動きとは別**。ユーザー指示）と
    `calibration/param/calibrate.yaml`（推定。各プログラムのオプションの既定値で、`params.py` が読む）。
    **名前は calibration を基準にする**（2026-10-15、ユーザー指示。プログラム・変数・コマンドに estimate を入れない）：全体は `calibrate.py`、
    R は `calibrate_noise.py`、NDT の R は `calibrate_ndt_noise.py`、取付と倍率は `calibrate_mount_scale.py`（図 `plot_mount_scale.py`）、
    走行 + 推定は `run_calibration.sh`。コマンドは `calibration`（走行 + 推定）・`calibrate`（録画から推定だけ）・`calibration_plan`・
    `calibration_params`。動きの名前・bag 名は `calibration`（`<target>_calibration_<日時>`）。それより前の録画 `gazebo_calib_test`・`gazebo_calib` は名前を変えていない
  - `calibration/calibrate_noise.py <bag> --out /root/ros2_ws/fig/noise_<名前> [--truth]`：**観測ノイズ R を真値なしで求める**（指令が一定の区間で
    観測から局所 1 次式を除いた残差の分散 x 残差の自己相関から求めた積分相関時間。NDT は取付で車体に直して当てはめる）。
    実機の録画にも使える。`--truth` は Gazebo だけの検算。図は `calibration/plot_noise.py`。
    **R_v は定速の直進区間の v の残差、R_omega は R_v と車輪の間隔から 4 R_v (s_omega/s_v)² / b²**（左右の車輪のノイズが独立と仮定。
    ユーザー指示。直接測った omega の残差も並べる）。車輪の間隔は Gazebo 0.492（`calibrate.yaml` の `noise.gazebo_tread`）、実機は
    whill_odometry の `tread_width`。**ノイズの推定は残差のヒストグラムと正規分布の図 `_hist.png` も出す**（ユーザー指示。縦軸は相対度数
    `Relative frequency`（全体を 1 とした棒ごとの割合）、棒は黒で縁取り、NDT の 6 つは範囲をそろえる。正規分布は頑健な σ（1.4826 MAD）の青の線 1 本だけ。
    R に使う残差の σ などは図の上の文字）。**R_ndt も走行中の残差から求める**（2026-10-15、ユーザー指示で `calibrate.py` から「真値 + ノイズ」の
    `calibrate_ndt_noise.py` を外した）
  - `calibration/calibrate_ndt_noise.py <止まる区間のある bag>`：**NDT の R を「真値 + ノイズ」の初期値で NDT を計算し直して求める**（ユーザー指示。Gazebo）。
    真値は止まった区間の `/wheelchair/pose` の平均。NDT だけを起動し、点群ごとに初期値を TF で出す。**止まる区間の、止まってから 1 s 後から
    10 s だけを、区間ごとに `ros2 bag play --start-offset` で速さ 1 倍で流す**（2026-10-15、ユーザー指示。再生は速くしない。全体を流すと約 9 分だった）。
    ノイズは 6 軸それぞれ正規分布で、σ は `calibrate.yaml` の `ndt_noise.sigma`。`--from-json` で図だけ描き直せる
  - `calibration/calibrate_mount_scale.py <bag> ...`：**LiDAR の取付位置（x, y, yaw。roll・pitch・z は参考）とオドメトリの倍率を真値なしで推定**
    （その場の旋回で LiDAR が描く円、旋回・直進の NDT とオドメトリの比。omega の倍率は旋回の絶対値の和で。推定用の動きは左回りだけなので
    左回りの値で、Gazebo では左 0.921〜0.924・右 0.913〜0.914 と向きで違う）。**取付の yaw は直進の区間で LiDAR の yaw − 車体の進む向き**を各時刻で求め、RANSAC で外れ値を除いて平均する
    （2026-10-16、ユーザー指示で決めた）：車体の位置（LiDAR − 取付）と LiDAR の yaw を前後 0.5 s で平滑化して各時刻の進む向きとの差を出し、
    オドメトリの v が安定していない時刻は使わない。RANSAC は 1 点を仮の値にして 0.3° 以内のインライアが最も多いものを選び、インライアの平均。
    （区間全体の円弧の当てはめ・始点と終点を結ぶ方法・Censi ほか（IEEE T-RO 29(2):475-492, 2013）の同時推定とも比べ、Gazebo で LiDAR を 5° 回した
    試験で 4 つとも 5.00〜5.01°、差は 0.02° 以内だった。比べたものは消した。`dev_log.md` の 49〜52）。各時刻の取付の yaw と最終値の図は `mount_scale_yaw.png`。
  - **パラメータ推定を走行とセットで**（2026-10-15、ユーザー指示）：`calibration/run_calibration.sh <target> [<bag 名>]`（コマンド `calibration`）が
    推定用の動き（その場で左に 4 周 → 止まる 5 s → 片道の直進 → 止まる。`motion.yaml` の 5 つ。2026-10-15 にユーザー指示で、4 方向に止まる段・右回り・最初の停止をやめた。
    Gazebo・実機で共通の 1 組。上限を超えると走らない）で走って録画し、`calibration/calibrate.py <target> <bag>`（コマンド `calibrate`）で
    R・倍率・取付（Gazebo は NDT の R も）をまとめて推定する。動きは `calibration/motion.py` が作り、`run_test.sh` に `PROFILES` で渡す
    （計画はコマンド `calibration_plan <target>`）。結果は `/root/ros2_ws/fig/calibration/<bag 名>/summary.yaml`（env には書き込まない。ユーザー指示）。
    推定は数秒
  - `eval/tune_run.py <入力 bag> <試行名> '<parameters の JSON>' ['use_ekf:=false']`（コンテナ内）：録画を左回転の
    8 秒前から `ROS_DOMAIN_ID=99` で再生し、指標（回転中の yaw 誤差・angle_diff・xy 誤差・速度が変わる 4 つの瞬間の跳ね
    `start_max` など。`transition_eval.py`）を 1 行 JSON で出す。JSON の `"__env__"` は env の最上位を上書き。
    `eval/tune_batch.py`（候補は `eval/batches/`、結果は `eval/results/`）、`eval/aggregate.py`（候補ごとの平均と幅）、
    `eval/summarize.py`。**同じ設定でもスコアは ±0.05 程度ばらつく（R が小さいと 1.0 と 3.0 のように大きく変わる）ので、
    良い設定は繰り返し、調整に使っていない録画で確かめる**。`eval/make_window_bag.py`：/wheelchair/odom を移動平均 n 個に置き換えた bag
  - **テスト走行と録画**（2026-10-13 からユーザー指示で Gazebo・実機共通。`drive/`）：`drive/run_test.sh <gazebo|red|blue|white> <動き> [<bag 名>
    [launch の追加引数]]`（bag 名を省くと `<target>_<動き>_<日時>`）（ホストからでも、自己位置推定のコンテナの中からでも実行できる。docker が無ければコンテナの中と
    みなしてその場で動かす。実機の PC ではコンテナの中から使う。Gazebo はホストからなら起動し直して推定器も起動、コンテナの中からは
    起動し直さない。実機は推定・whill_driver・LiDAR が動いていることを確かめるだけ）。走らせるのは `drive/drive_test.py`、動きは `drive/profiles.yaml`（spin・spin5・stops・accel・curve・slalom・reverse。
    速さは上限に対する割合、直進は距離・旋回は角度・円は半径なので上限を変えても形は同じ）、設定は `drive/config/<target>.yaml`（実機は車椅子の色ごとの `red.yaml`・`blue.yaml`・`white.yaml`。2026-10-15 に `real.yaml` から分けた）
    （上限：Gazebo v 1.5・後退 0.8 m/s・ω 1.0 rad/s、実機 0.5・0.3・0.5（ユーザー指示の既定）。走ってよい範囲：両方とも出発時の
    車体の中心を基準に前 10 m・後ろ 1 m・左右 2 m（ユーザー指示）。指令・姿勢・ジョイスティック・録画のトピック）。
    走る前に計算した軌跡が範囲に収まるか確かめ、走行中は範囲外・姿勢が 0.5 s 来ない（壁時計で測る）・ジョイスティック・時計の停止・
    区間 60 s・Ctrl-C/SIGTERM で 0 を送って止める（rclpy に Ctrl-C を処理させない。処理させると通信が先に閉じて 0 を送れない）。
    実機は計画を表示して `yes` で走り出す。`CONFIG=real_in_gazebo` で実機の設定を Gazebo で試せる（予行演習）。`CONFIG=gazebo_ground`（動きは `PROFILES=.../drive/profiles_velocity.yaml`）は車椅子を世界の原点の地面（ground_plane、z −0.4 から落とす）に置き、推定を起動しない（設定の `gazebo_launch_args` を Gazebo の launch に渡し、`localization: false`。2026-10-19、`dev_log.md` の 57）。録画は
    `/root/ros2_ws/bags/<target>/<bag 名>` と `_phases.txt`・`_info.yaml`（走行を途中で止めたら理由をメモに書く）。
    2026-10-13 より前の Gazebo の録画は旧版（`gazebo/drive_spin.py` 1 rad/s・1.5 m/s・時間で区切る、`drive_profile.py`、
    `drive.py` など。範囲は部屋全体）で、今の動きとは大きさが違う
  - `eval/compare_run.py`：**推定器の比較**（どの録画にも使える指標。stamp の時刻の 6 軸の誤差、実時間の誤差 = 各時刻に受信済みの
    最新の `/ekf_pose`、切り替え時の yaw、推定の古さ）。`batch <設定の JSON> <結果>`（`eval/batches/batch_compare*.json`、
    結果 `eval/results/results_compare.jsonl`）、`reeval`（残っている bag から指標を計算し直す）、`table`。
    図は `plot/plot_motion_compare.py report /root/ros2_ws/fig/compare <結果>`（`dev_log.md` の 22）。再生は `tune_run.py` の `replay`
  - `plot/`：`plot_spin.py`（誤差と angle_diff の時間推移。bag の読み込み・色・`capitalize_labels` など共通部品も）、
    `plot_axes.py`（6 軸と処理時間）、`plot_velocity.py`（v・omega の推移と遅れ）、`plot_scale.py`（omega の倍率）、
    `plot_odom_filter.py`（移動平均・倍率。`gazebo_changes.md` 用）、`plot_ekf_compare.py`（再生の比較。条件は `plot/configs/*.json`）、
    `check_*.py`・`compare_odom_timing.py`（オドメトリの検証）。`rerender_results.sh` で `results/` の図を全部描き直す
    （2026-10-14 に足りなかった約 30 個を加えた。NDT の R の図は約 9 分かかるので `FULL=1` のときだけ）
  - **録画（bag）の置き場所**（2026-10-13 からユーザー指示で Gazebo と実機を分ける。`eval/bag_paths.py`）：`test:/root/ros2_ws/bags/gazebo/<名前>`
    （Gazebo）・`/root/ros2_ws/bags/real/<名前>`（実機）、再生の出力はそれぞれの `tune/<試行名>`（結果の行の `out_bag`）。各録画に
    `<名前>_phases.txt`（動作の開始時刻）、`<名前>_drive.log`（テスト走行のログ。2026-10-14 から）、`<名前>_info.yaml`（Gazebo か実機か・録画日時・走らせ方・用途・録画時の推定器・Gazebo のオドメトリの移動平均（車輪の角速度から判定）・
    omega の真値との比）を付ける（`eval/bag_info.py write`、一覧は `eval/bag_info.py list`）。ツールの動作確認などの録画は
    `bags/<source>/check/<名前>`（2026-10-14 から。`run_test.sh` の bag 名を `check/<名前>` にする。比較・調整には使わない）。
    **録画・地図・図はホストの `docker/data/{bags,map,fig}` を割り当てたもの**（2026-10-14 から、ユーザー指示。
    コンテナを作り直しても消えない。コンテナの中で作ったファイルはホストでは root の持ち物）。古い図 `fig_old` は `data/fig_old`（割り当てていない）
- Docker 定義は `docker/`（`archive/localizer_ekf_docker` が基準。GitHub `MaeharaTakumi/localizer_docker`、Public。
  2026-10-15 に `localizer_rl_docker` から名前を変えた）
- `gazebo_changes.md`：Gazebo コンテナに加えた変更（場所・理由・元のファイル）の記録。**Gazebo を変えたら必ず追記する**

## 厳守事項（ユーザー指示）

- **回答は日本語で書く**（2026-10-26、ユーザー指示）。
- **Gazebo コンテナ `20261002`（8843520b410f）のファイルは、ユーザーの許可なしに編集しない**（読むのは可）。
  問題を Gazebo 側の設定変更で解決しない。
- **既存の自作 EKF（`ekf_localizer`）とその起動方法を壊さない。** `ekf_localizer` リポジトリは**ユーザーが指示したときだけ**変更する
  （2026-10-12：予測を水平面の中点法に、NDT の観測を base の姿勢にした。今の式の残し方を聞き、ユーザーの判断で humble を直接変更。2026-10-19：NDT で更新した直後の値を `/tf_ndt_update` に出す `publish_ndt_update_tf` を足した。2026-10-23：MATLAB 用の出力 `base_pose`・`vlp16_pose`・`vlp16_points` を足した。2026-10-26：`publish_trigger` とその 3 つをやめ、`predict_rate` 50 Hz の `/tf` だけにした。続けて `/tf_ndt_update`（`publish_ndt_update_tf`）もやめ、`publish_tf` もやめて TF を常に配信するようにした）。
  （robot_localization に切り替える機能は 2026-10-15 にユーザー指示で廃止した。下の「robot_localization（廃止）」）
- **曖昧な点は自分で判断せず、必ずユーザーに質問する。**
- **作業がひと区切りついたら（動作を確かめ、開発ログ・README を直したら）、確認を取らずに commit して push する**（2026-10-16、ユーザー指示。
  変更したリポジトリ（localization_tools・localizer_docker・localization_bringup など）ごとに。push したら commit を報告する）。
- GitHub リポジトリの作成・コンテナの作り直し・イメージの再ビルドは、ユーザーの確認を取ってから行う。

## コンテナ

| コンテナ | ID | イメージ | 役割 |
|---|---|---|---|
| `20261002` | 8843520b410f | `ubuntu_22_04` | Gazebo（車椅子モデル・ワールド・MATLAB 連携）。**編集禁止**（例外は下記の許可済みの変更のみ） |
| `test` | 3655c6997a90 | `localizer_maehara:latest` | **自己位置推定の開発用**（`docker/` からビルド。2026-10-15 に `test_maehara`・`localizer_rl:latest` から名前を変えた。2026-10-23 にフォルダの移動に合わせて作り直した） |

- 2026-10-23 にユーザーが `whillLocalizer`（これまでの自己位置推定、`whill_localizer:latest`）と `localizer_ekf`（`localizer_ekf:latest`）のコンテナとイメージを削除した。
  `localizer_ekf` は `archive/localizer_ekf_docker` から作り直せる。`ros2_0605`・`ros2_1024`・`ros2_v2`（自己位置推定とは別のコンテナ。ユーザー指示で残す）は触らない。

- **Gazebo コンテナへの許可済みの変更（2026-10-11）**：`/root/.bashrc` で `GZ_IP`・`IGN_IP`・`GAZEBO_IP` を 127.0.0.1、
  `GAZEBO_MASTER_URI=http://127.0.0.1:11345` にした（元は `/root/.bashrc.bak_20261011`）。Gazebo 自体（ROS ではない）の
  ignition-transport の探索マルチキャスト 224.0.0.7 が LAN（有線・無線）に出ていたのを lo だけにした。ただし Gazebo の master の
  TCP 11345、gzserver・gzclient の TCP 各 1 つ、UDP 10317・10318 は環境変数に関係なく 0.0.0.0 で待ち受ける（閉じるにはホストの
  ファイアウォールが必要。システム設定なのでユーザーが行う）。ROS 2（DDS）は `fastdds_localhost.xml` で 127.0.0.1 のみ（確認済み）。
  変更後も自己位置推定のコンテナと Gazebo は双方向に通信できることを確認済み。`wheel_separation_multiplier` は一時的に試して元に戻した
  （controller.yaml は元のファイルと一致を確認）。
- **Gazebo コンテナへの許可済みの変更（2026-10-12）**：`electric_wheelchair/config/controller.yaml` の diff_drive_controller に
  `velocity_rolling_window_size: 1`（既定 10 = 0.2 s の移動平均 → 0.02 s。元は同じ場所の `controller.yaml.bak_20261012`）。
  install の controller.yaml は src へのシンボリックリンク。値は起動時にしか読まれないので、変えたら Gazebo を起動し直す。
  場所・理由の一覧は `gazebo_changes.md`。
  移動平均は一時的に 10・倍率 [1, 1] に戻したあと、どちらも元（1、[1, 0.922]）に戻した（2026-10-12）。
- **Gazebo コンテナへの一時的な変更（2026-10-15、ユーザー指示。元に戻し済み）**：取付の yaw の試験のため `wheelchair_2.xacro` の LiDAR の取付を
  Gazebo に渡すモデルだけ yaw +5° にした（TF 用のモデルは 0°）。センサの `<pose>` を変えても、固定の関節のリンクがまとめられるときに上書きされて効かない。
  試験後に元のファイルと一致を確かめ、Gazebo を起動し直した（`gazebo_changes.md` の 3）。
- `test` は numpy 入り。`.bashrc` の通信設定は既定で Gazebo 用。
  `ROS_DOMAIN_ID=11`、Gazebo・MATLAB と同じ Fast DDS プロファイル（`/root/fastdds_localhost.xml`、localhost のみ）。
  実機（LAN 越しに LiDAR PC と通信）では `.bashrc` の通信設定ブロックを切り替える。
- イメージ `localizer_maehara:latest`（`docker/`（localizer_docker）86c9ae8。2026-10-15 にビルド。コンテナ `test` は 2026-10-23 にこのイメージから作り直し、`src/` の 4 つを写してビルド、localization_tools を `sync.sh push`、`.bash_history`・`.rviz2` を戻した）：`localization_bringup` は既定で `humble`（build-arg `BRINGUP_BRANCH`）、
  `localization_tools`（`main`）を `/root/ros2_ws/localization_tools` に clone、録画と図の置き場所 `/root/ros2_ws/bags/{gazebo,real}`・
  `/root/ros2_ws/fig`、地図 `/root/ros2_ws/map`（どれも `COLCON_IGNORE` 入り。`savemap`・地図選択も `/root/ros2_ws/map`）を作る。
  開発中のものは `src/` から `docker cp`（`localization_tools` は `sync.sh push`）で上書きする。
  `localization` コマンド（`.bash_aliases`）は `localization [red|blue|white|gazebo] [地図]`（既定 red。地図を省くと選ぶ画面。地図は名前 `SC10_4_0.05` でもパスでもよい）で、launch の `env:=<名前>` にする
  （2026-10-15 に環境変数 `WHILL` から引数に変えた。`scanmatch_cli <地図> [名前]` は地図を引数で渡す版）。
  Docker の README（コマンドの一覧など）はコンテナの `/root/ros2_ws/README.md` にもある（Dockerfile で写す。2026-10-15）。
  localization_tools のコマンド（2026-10-15、ユーザー指示）：`drive`（`drive/run_test.sh`。bag 名を省くと `<target>_<動き>_<日時>`）、`drive_list`（動きの一覧。
  `drive_list <target> <動き>` で走る前の計画）、`bags_list`（録画の一覧。`bags_list real`・`bags_list gazebo` で絞る）。（最初は `test_drive`・`test_list` だったが、ユーザー指示で `drive`・`drive_list` にした）。
- **録画・地図・図はホストの `docker/data/{bags,map,fig}`**（`docker-compose.yml` で割り当てる。2026-10-14 から）。
  コンテナを作り直しても消えない。地図 `SC10_4_0.05.pcd` は `data/map` にだけある（ホストには元の
  `Research/BIM/ifc/SC10_260507/blender/data/SC10_4.pcd` も）。作り直すと、`.bash_history`・`.rviz2`・`.ssh/known_hosts` の復元が要る。
  作り直したら、ROS 2 が Gazebo 用（DDS のソケットは送信用も含めて 127.0.0.1 だけ、TCP なし、LAN で 239.255.0.1 に参加しない）で
  あることを確かめる（ユーザー指示）。
- **名前**（2026-10-15、ユーザー指示）：リポジトリ `localizer_docker`、イメージ `localizer_maehara:latest`、コンテナ `test`、
  compose のプロジェクト `localizer_maehara`（それまでは `localizer_rl_docker`・`localizer_rl:latest`・`test_maehara`）。
- 自己位置推定のコンテナは同じ ROS_DOMAIN_ID・host network なので、同時に推定を動かすのは 1 つだけにする。
- 2026-10-15：ホストの NVIDIA ドライバの自動更新（libnvidia-egl-wayland 1.1.17 → 1.1.21）で、`test`・`20261002` が
  `docker start` で「libnvidia-egl-wayland.so.1.1.17: no such file」と起動しなくなった。ユーザーがホストに
  `/usr/lib/x86_64-linux-gnu/libnvidia-egl-wayland.so.1.1.17 → 1.1.21` のリンクを作って直した（作り直していない）。
  ドライバが更新されて同じことが起きたら、同じようにリンクを作る（sudo が要るのでユーザーが行う）。

## よく使うコマンド

コンテナ内の ROS 環境は `~/.bashrc` で読み込まれるので、`docker exec` では `bash -ic` を使う。

```bash
# コンテナへ反映（ホストで消したファイルはコンテナ側では消えない。.git も上書きされる）
docker cp src/localization_bringup/. test:/root/ros2_ws/src/localization_bringup/
# docker cp はホストの UID のまま置くので、所有者を直さないとコンテナ内の git が dubious ownership で止まる
docker exec test chown -R root:root /root/ros2_ws/src/localization_bringup

# ビルド（イメージと同じオプション）
docker exec test bash -ic 'cd /root/ros2_ws && colcon build --symlink-install --cmake-args -DCMAKE_BUILD_TYPE=Release --packages-select localization_bringup'

# テスト（gtest があるのは ekf_localizer: test_lagged_ekf, test_ekf_models）
docker exec test bash -ic 'cd /root/ros2_ws && colcon test --packages-select ekf_localizer --event-handlers console_direct+ && colcon test-result --verbose'
docker exec test bash -ic 'cd /root/ros2_ws && colcon test --packages-select ekf_localizer --ctest-args -R test_lagged_ekf'


# Gazebo の起動（20261002 の履歴と同じ。ファイルは編集しない）。止めるときは pkill -INT -f "ros2 launch connection_wheelchair"
docker exec -d 20261002 bash -ic 'ros2 launch connection_wheelchair connection_wheelchair.launch.py > /tmp/claude_gazebo_launch.log 2>&1'

# 自己位置推定の起動
ros2 launch localization_bringup localization.launch.py env:=gazebo                                         # Gazebo
ros2 launch localization_bringup localization.launch.py map_path:=/root/ros2_ws/map/<地図>.pcd             # 実機の車椅子 red（既定）
ros2 launch localization_bringup localization.launch.py env:=white map_path:=/root/ros2_ws/map/<地図>.pcd   # 実機の車椅子 white
#   引数: env（param/env/<env>.yaml の名前 gazebo・red・blue・white か yaml のパス。既定 red）, use_ekf（false で NDT が TF を出す）, map_path, rviz
```

- **`docker exec ... bash -ic` の中で `ros2 launch ... &` とバックグラウンドで起動しない。** ジョブ制御がないので SIGINT が無視され、
  `kill -INT` で止まらずノードが残る（同じ名前のノードが 2 組になり、推定が壊れたように見える。`setsid` でも直らない）。
  長く動かすものは `docker exec -d ... bash -ic '<コマンド>'` で起動して `pkill -INT -f` で止めるか、上のように
  フォアグラウンドで `timeout -s INT` にする（`replay.sh` は SIGINT を既定に戻してから exec している）。止めたら `ps` で確かめる。
- **`timeout` の中で `ros2 topic` などを使うときは `--no-daemon` を付ける。** そこで初めて ROS 2 の CLI のデーモンが起動すると、
  デーモンが `timeout` のプロセスグループに入り、時間切れのシグナルで壊れる（以後の `ros2 topic` が `!rclpy.ok()` で落ちる。
  直すには `ros2 daemon stop`）。`--no-daemon` ではトピックを探す時間が既定 0.5 s で 10 回に 1 回見つけ損ねるので、
  `--spin-time 3` を付ける（`ros2 topic echo`・`info`・`list`。`ros2 topic hz` は `--no-daemon` を受け付けない）。
- Gazebo の評価は `/ekf_pose`（LiDAR）を主に見る。真値 `/wheelchair/pose` は header が無いので bag の受信時刻を `/clock` で直して使う。
  地図と Gazebo の座標の間に xy 約 4.5 cm のずれがあり（止まっていても同じ）、どの推定器でも出る。ずれは場所で変わる
  （開始位置 x +41・y −21 mm、直進 16 m 先の x≈64 では x 0 mm）ので、長く走る録画の xy は推定器どうしの差で見る。

## グラフの作り方（ユーザー指示）

- 折れ線は、後方（先に描く・zorder が低い）の線ほど太く描く。真値は一番後ろの太い薄灰色の実線
  （`localization_tools/plot/plot_spin.py` の `TRUTH_COLOR`・`TRUTH_LW`・`widths_back_to_front()` を使う）。凡例の線幅もそろえる。
- 点線・破線はできるだけ使わない。系列の区別は色と太さで行う。色は dataviz の参照パレットから選び、`validate_palette.js` で検証する。
- **図の枠は 4 辺とも黒**（MATLAB の box on。2026-10-15、ユーザー指示。パラメータ推定の図は `calibration/plot_noise.py` の `box_on`）。
- **題・軸ラベル・凡例・注記の頭文字は大文字**（例 `Time from command switch [s]`、`Angular velocity [rad/s]`）。
  保存の直前に `plot_spin.capitalize_labels(fig)` を呼ぶ（先頭の語が `ekf_localizer` などの識別子ならそのままなので、
  凡例・題は `EKF (ekf_localizer)` のように大文字の語から始める）。
- 結果の図は `results/` に置く（git の外）。開発ログに埋め込む図は `dev_log_images/` に写す。描画は `test` の `/root/ros2_ws/localization_tools` で実行する（`plot/rerender_results.sh` で全部描き直せる）。
- 結果は `dev_log.md` に図を埋め込んで記録する。

## アーキテクチャ（NDT + EKF）

`/root/ros2_ws/src` のリポジトリ（すべて `MaeharaTakumi/*` の `humble`）：`lidarslam_ros2`（SLAM・地図作成）、
`lidar_localization`（パッケージ名 `pcl_localization_ros2`。NDT と `cloud_stamp_corrector`）、`ekf_localizer`（8 状態 EKF）、
`whill_odometry`（実機の車輪オドメトリ）、`localization_bringup`（launch・環境設定とオドメトリの共分散などの Python ノード）。
詳細は `localization_bringup/docs/node_graph.md`（ノード・トピック・QoS・TF 表）と `ekf_localizer/docs/ekf_flow.md`。

複数ファイルを読まないと分からない要点：

- **設定の階層**：`localization.launch.py` が `param/env/<env>.yaml`（ROS のパラメータファイルではなく launch が読む）から
  起動するノードとトピック（`nodes`）・フレーム・`static_tfs`・`stamp_mode` を決める。
  **`nodes.<ノード名>`**（2026-10-22、ユーザー指示。それまでの `topics`・`launch_odometry`・`joint_state_odometry` を置き換えた）：`enable` で起動するか
  （全ノード書く。`cloud_stamp_corrector` は書かず `stamp_mode` で決まる。launch 引数 `use_ekf:=`（ekf_localizer と odom_covariance）・`rviz:=` が優先、空なら環境ファイル）、
  `topics` に「ノードの中の名前: 実際の名前」を**全部書く**（launch はそのまま remap に渡す。つなぐときは両側を同じ名前にする。`/tf`・`/tf_static`・`/clock` は対象外）。
  ノードの処理は単純にする方針（ユーザー指示）で、ノードのコードは変えず、ekf_localizer の `*_topic`・whill_odometry の `input_topic_name` は launch が中の名前に固定して remap する。
  止めたノードの出力は録画や別の PC から来るものとして、つなぎ方は変えない。例外は 2 つ：EKF を起動しないと NDT が TF を出す（RViz の `/tf` も付け替えない）、
  `cloud_stamp_corrector` を起動するとほかのノードでその `input` と同じ名前を `output` に付け替える。パラメータは
  各パッケージの `param/*.yaml` → env の `parameters.<ノード名>` → launch が計算した値、の順に上書き。
  **上書きはノード名の節の一時 yaml（`_scoped`）で渡す**。辞書のまま渡すと launch_ros が `/**` の節にし、rclcpp は `/**` を先、
  ノード名の節を後に当てるので、パッケージの yaml にノード名の節があるパラメータは env で変わらなかった（2026-10-12 に直した）。
  効いたかは `ros2 param get` で確かめる。
  一時 yaml では、整数と小数が混ざった数のリストを小数にそろえる（`_normalize`。rcl は型の違う要素のリストを読めず、ノードが起動しない）。
  一時 yaml は launch ごとの `/tmp/localization_bringup_*/` に置き、launch が終わるときに消す（2026-10-14 まで `/tmp` に残し続けていた）。
  再生（`tune_run.py`）は、ノードが途中で落ちた回をエラーにする（止める合図より前のログの `process has died`）。止めるときに
  ekf_localizer がまれにセグメンテーション違反（exit code -11）で落ちる（3 回。止めた後なので結果には影響しない）。
- **NDT と推定器は TF で循環している**：`use_ekf:=true` のとき NDT は `publish_tf: false`・`use_tf_init_guess: true` になり、
  **点群の取得時刻**の map→LiDAR を TF から引いて NDT の初期値にする（`tf_init_guess_timeout` 0.05 s。引けなければ前回の解）。
  推定器は map→base の TF を、点群時刻を含む範囲で出し続ける必要がある。
- **`/ndt_pose`**：map→**LiDAR** の姿勢（base ではない）、stamp は点群の取得時刻、**共分散は未設定（0）**。
- **`/tf`・`/ekf_pose` の出し方**（2026-10-26 から、ユーザー指示。`dev_log.md` の 68）：ekf_localizer は `predict_rate`（50 Hz）の周期で、最新の状態を
  現在時刻まで予測した TF map → base・`/ekf_pose`（map→**LiDAR**、`PoseWithCovarianceStamped`、reliable + transient_local、KeepLast(1)）・
  `/ekf_odom` を出す。NDT の初期値と MATLAB はこの `/tf` を点群の stamp で引く（tf2 が前後の 2 つを補間）。`publish_trigger`（`timer`・`cloud`（実機）・
  `update`（Gazebo））はやめた。それより前の録画の `/tf` は、実機は点群の stamp ちょうどの予測値、Gazebo は更新するたびの事後推定値。
- **RViz の点群**（2026-10-19、`dev_log.md` の 53）：`/velodyne_points` は点群の stamp の時刻の TF（ekf_localizer の予測値）でmap に直されるので、NDT の解ではない。ユーザー指示で、ekf_localizer が NDT で更新した直後の値（点群の時刻の事後推定値）を TF map → base として `/tf_ndt_update`（`publish_ndt_update_tf`、`LaggedEkf::stateAfter`）に出し、2026-10-19〜26 は launch が RViz の `/tf` を `/tf_ndt_update` に付け替えていた。**2026-10-26 にユーザー指示で付け替えをやめ**、RViz は MATLAB と同じく `/tf` をそのまま読む（点群はその stamp の時刻の予測値の補間、視点の Target Frame `base_link` は最新の値。`dev_log.md` の 69）。続けてユーザー指示で `/tf_ndt_update` と、配信するノードの無かった RViz の EKFPose（`/ekf/pose`。lidar_localization の `rviz/localization2.rviz`）もやめた（`dev_log.md` の 70。`LaggedEkf::stateAfter` はテストとともに残す）。予測値との差は実機 blue で 10 m 先の点が平均 3〜4 cm・速度が変わる瞬間に最大 0.3〜0.5 m、更新値と NDT の解の差は blue の小さい R_ndt では 0.2 mm・0.01° 未満（`plot/plot_prior_posterior.py`、`dev_log.md` の 53・54。NDT の解で直した点群 `/aligned_points` を出す版（53）は 54 でやめた）。RViz の既定の視点は `TopDownOrtho`・Target Frame `base_link`（自車両を中心に真上から、向きは地図で固定。2026-10-19、ユーザー指示。`dev_log.md` の 55）。RViz の画面は localization_tools の `record_rviz.sh`（ホストで実行。RViz の窓を探して ffmpeg の x11grab `-window_id` で録る。コンテナに ffmpeg は無い。`dev_log.md` の 56）で録画する。RViz2 は設定ファイルの `Hide Left Dock`・`Hide Right Dock` を起動時に効かせない（欄を出さずに録るときは、録画用の設定の写しから Displays・Views などのパネルを除く）。rviz2 は SIGINT で終わらないことがあるので、止まらなければ SIGKILL（`dev_log.md` の 57）。
- **MATLAB が使う姿勢と点群**（2026-10-26、ユーザー指示。`dev_log.md` の 68。61〜67 は ekf_localizer の MATLAB 用の出力 `/localization/base_pose`・
  `vlp16_pose`・`vlp16_points` を購読していたころで、それらはやめた）：MATLAB の CR_debug は sensor(1) で `/velodyne_points` をそのまま購読し、
  `ros2tf`（`/tf`・`/tf_static` を C++ 側のバッファに既定 10 s 溜める）から、sensor(5)（Matching）は最新の map → base（後輪間中心。base は Gazebo が
  `base_footprint`、実機が `base_link`）を `Plant` に、sensor(8) は点群の stamp の時刻の map → velodyne（事前推定値。NDT の初期値と同じ値）を
  `data.LIDAR_pose` に入れる（`ROS2CommManager` が `ros2tf` を作り `SensorFetcher.setTfTree` で渡す）。その時刻より後の TF がまだ無ければ待たずに前の組を使い
  （`data.LIDAR_waiting`）、次の周期にその時点の最新の点群で引き直す（ユーザーが選んだ）。共分散は無い。sensor(8) を書いていない main では false として動く。
  記録の図 `+plotter/myplotResult.m` は `Position`・`Angle`（Plant）、`Position_LiDAR`・`Angle_LiDAR`・`Trajectory`・`LiDAR_pair_interval`（`dev_log.md` の 63）。
  点群地図と取得点群の動画は `+plotter/myplotPointCloudVideo.m`（点群は同じ stamp の `LIDAR_pose` で直す。車両中心（後輪間中心）は黒い点。main.m の
  `makeVideo`・`mapFile`。`dev_log.md` の 64・65）。`data.Now` はデータを受け取った直後の ROS の時刻（Gazebo・録画の再生は MATLAB のノードの
  `use_sim_time` を true にして `/clock`）で、`myplotResult` の `LiDAR_age` が点群の古さ。録画の再生 → 自己位置推定 → MATLAB → 図・動画は
  localization_tools の `matlab/replay_matlab.sh`（ホストで実行。`dev_log.md` の 65）。
  NDT の解は実機 blue の走行中で点群が届いてから平均 34 ms（50 ms 以内 99.4 %）、Gazebo で平均 37〜43 ms。
  確かめるのは localization_tools の `eval/replay_outputs.py`（録画全体を再生して `/tf` などを録る）と `plot/plot_matlab_outputs.py`（`/tf` の周期、
  点群の stamp より後の TF が届くまでの時間、事前推定値と NDT の解・NDT で更新した直後の値・真値の差。`compare` で前後を比べる）。
  実機の録画をコンテナの中で再生すると大きい点群が受け手の側で落ちる（blue で NDT が解くのは半分ほど。出力を止めても、0.5 倍の速さでも同じ）。
  原因（`dev_log.md` の 66）：ROS 2 は 127.0.0.1 の UDP だけ（共有メモリなし）で、ソケットの受信バッファが 208 kB（`net.core.rmem_max` も同じ）。
  314 kB の実機の点群は断片があふれ、best effort の受け手（NDT・ekf_localizer・Gazebo モードの MATLAB）は約半分を失う（reliable は再送で全部届く。
  151 kB の Gazebo の点群は 98 % 届く）。**2026-10-26 にユーザーがホストで `net.core.rmem_max`・`rmem_default` を 8388608（8 MB）にし、
  再生でも全部届くようになった**（NDT が解くのは 1515 / 1527 で走行中と同じ程度。`dev_log.md` の 67）。`sysctl -w` なので再起動で戻る
  （`/etc/sysctl.d/` には書いていない）。sudo は Claude Code の中のシェルからは動かない（no new privileges）ので、ユーザーがアプリの外の端末で行う。
  実機の MATLAB は `/velodyne_points` を UDP で受けるので、実機の PC でも同じ設定にする。
- **`/initialpose`** は NDT が **LiDAR の姿勢**として扱う（RViz の 2D Pose Estimate は z=0）。
- **ekf_localizer の予測**（`src/ekf_core.cpp` の `propagate`、2026-10-12 から）：水平面を移動すると仮定した中点法（RK2）。
  yaw_m = yaw + omega dt/2、x += v dt cos(yaw_m)、y += v dt sin(yaw_m)、yaw += omega dt。roll, pitch による v, omega の分解はしない。
  z, roll, pitch は予測では動かさず Q のノイズだけ（以前は円弧の厳密積分で v cos(pitch)、z は −v sin(pitch)）。Gazebo の再生で
  yaw・xy は同じ、z の誤差は少し小さい（`dev_log.md` の 18）。坂では NDT が途切れると z が遅れる（テスト `SlopeZHeldDuringNdtOutage`）。
- **ekf_localizer の NDT の観測**（`src/ndt_model.cpp`、2026-10-12 から）：LiDAR の姿勢を取付で base の姿勢 T_L·T_BL⁻¹ に直し、
  `R_ndt`（LiDAR、対角）をヤコビアンで伝播した相関込みの 6×6 で、6 成分を 1 回で更新する。
  ゲートは `gate_ndt` 1 つ（`ekf.yaml` は 1.0e5 で実質無効）。4 段の更新・ロックアウト・`gate_horizontal`・`gate_1d`・`lockout_count` は
  削除した。今の R_ndt では base の x, y の σ が約 22 cm・roll/pitch との相関約 0.9 になるので、相関を捨てると結果が変わる。
  再生の結果は LiDAR の姿勢で観測していたときと同じ程度（`dev_log.md` の 19）。`/ekf_pose` の共分散は `lidarPoseJacobian` で出す。
- **ekf_localizer の当時の動かし方**（2026-10-12、commit 0fb1488・2739d6d、GitHub の humble に push 済み）：`time_source`（`stamp` 既定 / `receipt`）と
  `publish_trigger: update`（NDT・オドメトリで更新するたびに、その時刻の事後推定値を TF・`/ekf_pose` に出す）を追加。
  `receipt` はオドメトリを受信した時刻、NDT はその点群（`points_topic`）を受信した時刻にする（ekf_localizer が点群も受け取って stamp ごとに
  覚える）。`/ndt_pose` の受信時刻にすると NDT の計算の遅れ（56〜67 ms）で大きく悪化した（スコア 6.9）。
  Gazebo（`gazebo.yaml`）は 2026-10-26 まで `publish_trigger: update`（時刻は stamp）。再生で timer（20 Hz）と同じか少し良く、ばらつきが小さかった
  （6 回 0.91〜1.02、timer 4 回 0.95〜1.19）。receipt + update は 1.03（`dev_log.md` の 20・21）。`publish_trigger` は 2026-10-26 にやめた（上の「`/tf`・`/ekf_pose` の出し方」）。
- **オドメトリ**：使うのは `twist.linear.x`・`twist.angular.z`。Gazebo は diff_drive_controller の odom を `gazebo_bridge` が
  中継する `/wheelchair/odom`（50 Hz、best effort、**共分散 0**）、実機は `whill_odometry`（共分散あり）。Gazebo の速度は
  2026-10-12 から移動平均なし（`velocity_rolling_window_size: 1`）。**それより前の録画は 0.2 s の移動平均で約 0.1 s 遅れている**
  （録画を再生して比べるときは、どちらの録画かに注意。移動平均 1 の録画は `spin360_w1_ekf`（調整用）と `spin360_w1_ekf2`（確認用））。
  MATLAB（`Project-SIP/main` の `SensorFetcher.m`）も Gazebo モードで `/wheelchair/odom` の v・omega を使う。
- **Gazebo 側の TF**：`diff_drive_controller` は `enable_odom_tf: false`。`robot_state_publisher`（URDF）が
  `base_footprint→base_link`（z 0.10）`→velodyne_base_link`（-0.17, 0, 1）`→velodyne`（z 0.0377）を配信し続ける。
- **取付 TF**：実機は launch が環境ファイル（`red.yaml` など）の `static_tfs` を配信し、Gazebo は URDF（Gazebo 側の robot_state_publisher）を使う
  （`gazebo.yaml` の `static_tfs` は空。ユーザー指示）。Gazebo で launch からも `velodyne` などを配信すると親が 2 つになり、
  **同じ実行の中でもノードごとに違う取付を読んで**、base か `/ekf_pose` に z 約 0.16 m・yaw 約 1° のずれが出た（実測。
  各ノードの起動ログの `mount base_footprint -> velodyne` で分かる）。
- **NDT の初期値**（`pcl_localization_component.cpp` の `cloudReceived`）：起動時は env の `initial_pose_*`（LiDAR の姿勢）。
  毎スキャン、`use_tf_init_guess` なら推定器の TF map→LiDAR を**点群の stamp**で引く（最大 0.05 s 待つ）。引けないとき
  （推定器の初期化前、`/initialpose` から 1 秒間）は前回の NDT の解（または与えた初期姿勢）。`src/ndt_initial_guess.c` はビルドされておらず使われていない。
- **angle_diff**（`/localization_debug` の data[4]）は、初期値と NDT の解の**それぞれの回転の大きさ**（単位行列からの角度）の差。
  2 つの姿勢の間の角度ではないので、yaw が 0 や ±π の付近では実際より小さく出る。

## 実機（ラズパイは `acsl-tcu/project_whill`）

車椅子（WHILL CR）と LiDAR（VLP-16）はラズパイ（ホスト名 `Drp5_whill_<色>`）の project_whill が動かす（cyclonedds）。
**車椅子は blue・red・white の 3 台**（ユーザー指示ですべて使えるようにした。MATLAB の `Project-SIP/main` は red・white だけ、
whill_odometry のコードの既定は red、`param/odometry.yaml`（2026-10-15 に `config/` から移した）は blue。launch が環境ファイルの色で上書きする）。色は自己位置推定の launch の環境 `env:=<色>`
（`param/env/red.yaml`・`blue.yaml`・`white.yaml`。`nodes.whill_odometry.topics.motor_speed` の `/Drp5_whill_<色>/...` が違う（blue は R・Q・取付・倍率もユーザーが変えた）。既定 red。
2026-10-15 にユーザー指示で `real.yaml` と `whill:=` 引数をまとめ、環境ファイルの `whill` と `{whill}` の置き換えもやめた）、テスト走行の
`run_test.sh <red|blue|white>`（`drive/config/<色>.yaml`。`WHILL`・`--whill` もやめた）で選ぶ（両方を同じ色にする）。`run_test.sh <色>` は
選んだ色の `cmd_vel` を受けるノードが無ければ止める。
**自己位置推定の PC と LiDAR の PC（ラズパイ）は時刻同期している**（2026-10-15 にユーザーが確認）。点群とオドメトリの時刻は環境ファイルの
**`stamp_mode`** でそろえて決める（2026-10-15、ユーザー指示で `cloud_stamp_correction` を `clock_synced: true / false / auto` に置き換え、
2026-10-22 にユーザー指示でノードと同じ名前の `stamp_mode` にした。`wall` ではなく `receipt` もユーザーが選んだ）：
`stamp`（実機・Gazebo とも今はこれ）は stamp をそのまま、`receipt` は受信した時刻、`auto` は |受信した時刻 − stamp| が
`clock_offset_threshold`（既定 0.1 s）以上なら受信した時刻・小さければ stamp（1 つずつ判断）。launch は値をそのまま、点群の `cloud_stamp_corrector`
（lidar_localization。`mode`。`stamp` のときは起動しない）とオドメトリの `odom_covariance` の `stamp_mode` に入れる。
環境ファイルに `clock_synced` が残っていると launch はエラーで止まる。
sim time で `/clock` を受け取る前（今の時刻が 0）は stamp のまま（直す前は Gazebo の起動直後にオドメトリの時刻を 0 にしていた）。
Gazebo を `auto` で走らせると、受信した時刻 − stamp は点群 −4〜+7 ms、オドメトリ 0 ms で、受信した時刻に切り替わることは無かった。
実機のずれ（点群の転送の遅れを含む）は未測定なので、`auto` を使う前に、`auto` のログ（10 s ごとの「receipt time used for …」）で確かめる。
時計のずれを推定して直す `estimate` は廃止した。whill_odometry は `use_stamped_input: true` でラズパイが付けた `motor_speed_ts` の stamp を
使う（stamp が 0 のとき受信時刻で代える処理は、0 にならなくなったので 2026-10-15 にユーザー指示で外した）。
自己位置推定の PC（コンテナ `test`）から LAN 越しに使う。録画するのは点群・`motor_speed_ts`・`cmd_vel`・バッテリーと推定の出力
（`motor_angle_ts`・`joy_ts`・`speed_mode`・GNSS は録らない。ユーザー指示。`joy_ts` は走行中の監視に使う）。トピック：
- `whill_driver`（名前空間 `/<ホスト名>/whill_node`）：`~/cmd_vel`（Twist、m/s・rad/s）を受ける。指令が 1 s 途切れると止まり、
  ジョイスティックが倒れていると指令は無視される。変換の上限は前進 1.67 m/s、後退 0.56 m/s、旋回 約 0.83 rad/s。
  `~/motor_speed_ts`（左右輪の速度 km/h、x = 右・y = 左。whill_odometry の入力）・`~/motor_angle_ts`・`~/joy_ts`・`~/speed_mode`・
  `~/battery_*` を 50 Hz で出す（stamp はラズパイの時計）
- velodyne：`rpm 1200`（**20 Hz**）。launch に `namespace:=/<ホスト名>` を渡しているが公式の launch は使わないので `/velodyne_points`
  （MATLAB も実機で `/velodyne_points` を使う。`run_test.sh <色>` は録画するトピックがあるか確かめて表示する）
- RTK-GNSS（ublox、屋外）：MATLAB は `/ublox_gps_node/fix` を使う（録画はしない）

## robot_localization（廃止、2026-10-15、ユーザー指示）

- robot_localization（2 段 EKF。NDT を base に直す `robot_localization_adapter.py` を挟む）を `estimator:=robot_localization` で
  切り替えて比べていた（2026-10-11〜13、`dev_log.md` の 1〜23）。同じ設定（R・Q・`/ekf_pose` を当時の `publish_trigger: timer` で出す）で Gazebo の 6 つの動きを
  再生して比べると、加減速・スラローム・後退・停止はほぼ同じ、その場の回転（yaw 0.21 対 0.32°）と曲線（0.13 対 0.16°）は
  ekf_localizer のほうが良かった（`dev_log.md` の 23）ので、ekf_localizer だけにした。
- 消したもの：localization_bringup の切り替え・adapter・`robot_localization.yaml`（コードは `robot_localization` ブランチの 23767ee に残る）、
  localization_tools の robot_localization の再生・合成データのテスト・候補・結果の行（476480a より前の履歴に残る）、Docker の
  `ros-humble-robot-localization`、robot_localization の録画 7 個と再生の出力 193 個・前のイメージ `localizer_rl:latest`（ユーザーが消した）。
- `results/` の robot_localization を含む図（`spin_results`・`spin360_*`・`axes_*`・`transition_compare`・`velocity*`・`scale_*`・
  `compare_*`・`qg_*`）は開発ログの記録として残すが、`rerender_results.sh` では描き直さない。
- robot_localization について分かったこと（参考）：姿勢の観測を base の姿勢として扱い取付を補正しない、共分散 0 を 1e-9 にする、
  `lookupTransformSafe` は指定時刻の TF が無いと警告なしに最新の TF で代用する（回転中に yaw がずれる）、
  先にオドメトリが来ると位置 0 で初期化されて NDT で戻せない、`child_frame_id` が TF に無いオドメトリを黙って捨てる。

## Gazebo で調べたこと（ekf_localizer）

- NDT 単体との比較（同じ録画の再生、`results/axes_*.png`）：NDT 単体の `/ndt_pose` は yaw の誤差が小さく切り替え時も跳ねないが、
  点群の stamp から平均約 50 ms・最大 165 ms 遅れて 10 Hz で届き、止まっていても y が ±3 cm 程度ばたつく。
  NDT の位置合わせは動いている間 平均 35〜41 ms・最大 120〜150 ms（止まっていると約 15〜20 ms）。EKF 使用時は NDT が
  TF（点群の時刻）を待つので、`/ndt_pose` の遅れは ekf_localizer（当時の `publish_trigger: timer` 20 Hz。今は `predict_rate` 50 Hz）で平均 68 ms。
  ekf_localizer の `/ekf_pose` の遅れは約 0 ms（stamp が配信時刻の予測値）。
- **オドメトリの R**（`scripts/odom_covariance.py`）：`use_ekf:=true` のとき、オドメトリは `odom_covariance` で
  R_v = R0 + a0·v² + a1·ω²、R_ω = R0 + a2·v² + a3·ω²（Nav2 AMCL の odom_alpha と同じ考え方）の共分散を付けて
  `/localization/odom` に中継される。ekf_localizer は launch が `odom_covariance_source: message` にして読む。
  既定 alpha = 0（固定 R、今までと同じ動きを再生で確認）。速さに応じた R は、再生の比較でばらつき（スコア ±0.04）を超える改善がなく、
  ω に応じて R を大きくすると悪化した（回転中の yaw 0.63 → 0.73〜0.90°）。
  ROS 2 の標準にオドメトリの R を時変にする機能は無い（diff_drive_controller の共分散は固定パラメータ）。
  2026-10-13 に移動平均 1 の録画（`spin360_w1_ekf2`）で alpha を試し直しても改善なし（`dev_log.md` の 24。
  v に応じた R は回転→前進の跳ねを小さくするが停止の跳ねを大きくする。omega の Q 10 が大きく、R_ω を 11 倍にしても omega は
  ほぼオドメトリに従う）。真値なしで測ったオドメトリの残差（σ_v 0.0001、σ_ω 1 rad/s で 0.011）は `R_odom` よりずっと小さい。
  `R_odom` を 1e-6 にしても（alpha あり・なしとも）その場の回転の yaw は変わらない（`dev_log.md` の 25。omega のゲインは
  0.976 → ほぼ 1 で、もともとオドメトリにほぼ従っている）。`R_odom` をちょうど 0 にすると ekf_localizer は `ekf.yaml` の `R_odom` に戻す。
- **遅れの補正と Q**（2026-10-11、移動平均 10 のころ）：`odom_covariance` に `odom_delay`（stamp を戻す）と `accel_noise_tau`
  （R に (τ·加速度)²）を追加。`odom_delay: 0.09` と Q の omega 10 で、調整に使っていない録画の 4 つの瞬間の yaw 誤差の最大の平均は
  4.3 → 3.3°（NDT 単体 1.7°）、定常の回転中 0.54〜0.59°。加速度に応じた R と速さに応じた R は効かない（速度が変わる間オドメトリを
  信じないと、古い omega のまま予測して悪化）。遅れの補正なしで Q だけ上げても効かない。瞬間ごとの値は再生ごとのばらつきが大きいので、
  比べるときは 2 回以上流す。移動平均を 1 にしてからは `odom_delay: 0`。実機（whill_odometry）の遅れは未測定。
  **2026-10-15 にユーザー指示で `odom_covariance` の `odom_delay` を外した**（ekf_localizer の `odom_delay` と同じことをしていたため。
  遅れの補正は ekf_localizer の `odom_delay` だけ。過去の候補ファイルの `odom_covariance.odom_delay` は `ekf_localizer.odom_delay` に書き換えた）。
- **v・omega の推移**（`results/velocity_*.png`、移動平均 10 のころ）：Gazebo のオドメトリは真値より omega が約 97 ms、v が 53〜70 ms 遅れる。
  回転中、オドメトリの omega は 0.99 rad/s だが真値は 0.915 rad/s（約 8.5 % 大きい。滑り）。停止の瞬間に真値の omega が
  -0.48 rad/s に振れるが、オドメトリには出ない。stamp を戻してもオドメトリが届くのは約 0.1 s 後なので、実時間の推定には遅れが残る。
- **車輪からオドメトリへの変換**（2026-10-11、`check_wheel_odom.py`）：Gazebo の diff_drive_controller は既定で
  `position_feedback: true`・`velocity_rolling_window_size: 10`（直近 0.2 s の回転角の変化 / 0.2 s）。式 v = r(wR+wL)/2、
  omega = r(wR-wL)/b と r 0.1325・b 0.492（URDF の形状と一致）で再計算すると /wheelchair/odom と一致（RMS 0.003 m/s、0.005 rad/s）。
  前進の立ち上がり・停止では車輪が車体より 47〜59 ms 先に速度を変え（1.5 m/s の段差は摩擦 mu 1.0 で出せる加速度を超え、車輪が滑る）、
  回転では車体が車輪にほぼ遅れず付いていく。回転→前進では車輪が回転をやめてから車体の回転が止まるまで約 0.1 s。
  回転中の実効的な車輪間隔は 0.532〜0.535 m（設定より約 8 % 広い）→ オドメトリの omega が 8〜9 % 大きい。直進の v は真値と一致。
  実機の whill_odometry の式（v = (vL+vR)/2、omega = (vR-vL)/tread、km/h -> m/s、右輪の符号反転、移動平均なし）は正しいが、
  tread 0.495 m などの値は実機のデータが無いので未確認。
- **オドメトリの倍率の補正**：`odom_covariance` の `odom_scale` [v, omega]（既定 [1, 1]）。Gazebo は omega 0.922
  （真値 / オドメトリ）。Gazebo 側で `wheel_separation_multiplier: 1.085` にするとオドメトリの omega が真値と一致し、
  推定も良くなることを確かめたうえで、Gazebo は元に戻して推定側で補正した。定常の回転中の yaw 誤差 0.56〜0.59 → 0.18〜0.19°、
  angle_diff 平均 0.74 → 0.22°。速度が急に変わる瞬間の跳ねは変わらない（主因はオドメトリの情報の遅れ）。実機の omega の倍率は未校正。
- **車輪の角速度からのオドメトリ**（2026-10-12、`scripts/joint_state_odometry.py`、env に `joint_state_odometry` を書いたときだけ起動する任意の機能）：
  移動平均 10 の /wheelchair/odom の代わりに試した。反転の yaw の跳ね 5.2 → 1.25°、回転→前進は車輪の滑りで悪化（1.2〜1.7 → 2.6〜3.2°）、
  停止の瞬間は NDT 単体（1.9°）より悪い（2.4〜5.2°）。実運用の `gazebo.yaml` は `/wheelchair/odom`（ユーザー指示）。
- **Gazebo の移動平均を 1 にした**（2026-10-12、ユーザー許可。`gazebo_changes.md`）：`/wheelchair/odom` が車輪の回転角の 1 周期の差
  （0.02 s）になり、omega の遅れは +98 ms → +2〜3 ms、立ち上がり 160 → 40 ms（真値 60〜70 ms）、回転中のばらつき 0.010 → 0.014 rad/s
  （真値 0.014）。倍率は変わらない（0.923）。同じ録画 `spin360_w1_ekf` の再生（移動平均 10 は `make_window_bag.py` で再現）で yaw の跳ねは
  回転開始 5.0 → 0.7°、反転 10.2 → 1.7°（NDT 単体 1.7・1.8°）。回転→前進 1.5 → 4.0°、停止 4.1 → 4.9° は悪化：回転→前進では車輪が
  車体より約 90 ms 早く回転をやめ、停止では車体がブレーキで −4.35° 向きを変えるのにオドメトリは +1.43°（逆向き）。
- **R を真値なしで求めた結果と Q の調整**（2026-10-12、`dev_log.md` の 13・14）：`calibration/calibrate_noise.py` の R（動いている区間）は
  NDT x・y・z・yaw が真値との差とよく合う（σ 4・8・5 mm、0.23°）。オドメトリ omega（tau_int 11）と NDT roll・pitch（6〜7）は誤差が
  時間的につながっていて、補正すると σ 0.033 rad/s、0.10°（真値との差 0.12°）。今の R（NDT σ 100 mm・yaw 1.8°・roll/pitch 9.9°、
  オドメトリ σ v 0.05・omega 0.07）よりずっと小さい。この R で Q を合わせ直しても（最良 x・y 5e-3、z 5e-4、roll・pitch 5e-3、yaw 5e-4）、
  調整用の録画で今の設定と同程度、調整に使っていない録画では悪化（スコア 1.47、定常の yaw 0.19 → 0.30°）、しかも再生ごとに大きく変わる。
  R が小さいと EKF が遅れて届く NDT に飛びつき、それが次の NDT の初期値になるので振動することがある（`results/qr_unstable.png`）。
  **`gazebo.yaml` の R・Q は変えていない**。次の方針はユーザーの判断待ち。
- **NDT の R を「真値 + ノイズ」の初期値で求めた結果**（2026-10-12、`dev_log.md` の 15）：初期値が真値なら NDT の解はほとんど
  ばらつかない（0.3 mm、0.03°）。運用中の EKF の誤差の 2〜4 倍のノイズ（x・y 20 mm、z 10 mm、roll・pitch 0.3°、yaw 1°）を
  足すと σ x 14・y 28・z 21 mm、roll・pitch 0.2°、yaw 0.74°。**NDT は真値の近くの別の解に収束する**（yaw +1°・−1.2°、y ±40 mm。
  初期値の yaw が 0.5° 以上ずれると逆の側の解になりやすい）。R が小さい EKF の振動はこれが原因。この R_ndt は調整に使っていない録画で
  ekf_localizer を悪化させた（8 回中 6 回が振動に入りスコア 1.6〜2.5、今までの R_ndt は 5 回とも 0.94〜1.11）ので、`ekf.yaml` の値のまま。
  **再生の比較は 2 回では足りない（振動に入るかどうかで結果が分かれる）。4 回以上流して、1 回ごとの値も見る（`SHOW_RUNS=1 eval/aggregate.py`）**。
  地図と Gazebo の座標のずれは開始位置で x +41 mm、y −21 mm（止まっていても同じ。場所で変わる）。
- **取付位置とオドメトリの倍率の推定**（`dev_log.md` の 16）：真値なしで omega 0.9244（設定 0.922）、v 0.9998、取付 x −171.3 mm・
  y −3.7 mm（URDF −170・0）、yaw・roll・pitch 0.05° 以内。z は地図の床から 1.175 m（URDF 1.138 m。参考）。
- **いろいろな動きでの精度**（`dev_log.md` の 22・23、同じ録画を 6 つの動きで各 4 回再生）：ekf_localizer の yaw 誤差の平均は
  その場の回転 0.21°・曲線 0.13°、z 7 mm。`gate_ndt` は 1e5 で実質無効。Gazebo の録画には 1〜3 ms 違いの点群の組がある（1 周の録画で 12 組）。
- **地面でのオドメトリと真値の速度**（2026-10-19、`dev_log.md` の 57、`plot/plot_odom_truth.py`）：原点の ground_plane で、その場の回転の omega は真値 / オドメトリ 0.907（0.5 rad/s）・0.901（1.0 rad/s）で、建物の床の 0.922〜0.924 より小さい（理由は未調査）。直進の v は 0.5・1.0 m/s とも一致（1.000）。
- 未確認：実機（`env:=red` など）。
