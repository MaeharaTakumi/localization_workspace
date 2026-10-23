# Gazebo コンテナ（20261002）の変更記録

ユーザーの許可を得て変更したものだけを記録する。

| 日付 | 場所 | 変更 | 理由 | 元のファイル |
|---|---|---|---|---|
| 2026-10-11 | `/root/.bashrc` | `GZ_IP`・`IGN_IP`・`GAZEBO_IP` を `127.0.0.1`、`GAZEBO_MASTER_URI=http://127.0.0.1:11345` | Gazebo 自体の通信（探索のマルチキャスト 224.0.0.7）が LAN に出ていたので、ローカルに限る | `/root/.bashrc.bak_20261011` |
| 2026-10-11 | `controller.yaml` | `wheel_separation_multiplier: 1.085` を一時的に試し、**元に戻した**（現在は変更なし） | omega の倍率のずれの原因の確認（下の「倍率の追加」） | — |
| 2026-10-12 | `/root/ros2_ws/src/wheelchair/electric_wheelchair/config/controller.yaml` の `/wheelchair/diff_drive_controller` | `velocity_rolling_window_size: 1` を追加（既定は 10） | オドメトリの速度の 0.2 s 移動平均をやめる（下の「移動平均の変更」） | `controller.yaml.bak_20261012`（同じディレクトリ） |
| 2026-10-12（一時的） | 同上 | `velocity_rolling_window_size: 10`（既定の 0.2 s 移動平均）に一時的に戻したあと、**1 に戻した**（現在は 1） | ユーザー指示 | — |

- `controller.yaml.bak.20261002` は以前からあるユーザーのファイル（触っていない）。
- 戻すときは元のファイルを書き戻して Gazebo を起動し直す。

## 1. 移動平均の変更（Gazebo 側、2026-10-12）

- diff_drive_controller はオドメトリの速度を直近 10 周期（`update_rate` 50 Hz で 0.2 s）の平均にしている。
  このため速度の段差が 0.2 s の直線になり、真値より約 0.1 s 遅れる。
- `velocity_rolling_window_size: 1` で直近 1 周期（0.02 s）の車輪の回転角の差だけを使う。
  変更後の `/wheelchair/odom` は、車輪の回転角から計算した値と一致した（RMS 0）。

| | omega 10→90 % | omega の遅れ（回転開始 / 反転） | v の遅れ（前進開始 / 停止） | 回転中の omega のばらつき |
|---|---|---|---|---|
| 真値 | 60〜70 ms | — | — | 0.014 rad/s |
| 移動平均 10（変更前） | 160 ms | +98 / +98 ms | +70 / +58 ms | 0.010 rad/s |
| 移動平均 1（変更後） | 40 ms | +2 / +3 ms | −61 / −68 ms | 0.014 rad/s |

- omega は真値とほぼ同じ時刻・傾きで変わるようになった（大きさの違いは次の倍率で補正）。
- v（補足）は真値より早く変わる。1.5 m/s の段差で車輪が滑り、前進開始では車輪が先に約 1 m/s まで上がり、
  停止では先に約 0.5 m/s まで下がるため（移動平均で隠れていた。Gazebo の物理の結果で、計算の誤りではない）。
- `/wheelchair/odom` を使う他のもの（MATLAB の `Project-SIP/main` の `SensorFetcher.m` の `Plant.odom`、Gazebo モード）
  の入力も同じく変わる。実機の WHILL の `motor_speed_ts` にも移動平均はない。

![移動平均 omega](dev_log_images/odom_window_omega.png)

![移動平均 v](dev_log_images/odom_window_v.png)

## 2. 倍率の追加（推定側で補正、Gazebo は元のまま）

- Gazebo のオドメトリの omega は真値より約 8 % 大きい（回転中 0.99 rad/s、真値 0.92 rad/s）。
  車輪が滑り、実効的な車輪間隔が 0.532〜0.535 m と設定（0.492 m）より広いため。移動平均を変えても同じ（比 0.923）。
- Gazebo の `wheel_separation_multiplier: 1.085` で一致することを確かめたうえで Gazebo は元に戻し、
  推定側（`localization_bringup` の `gazebo.yaml`、`odom_scale: [1.0, 0.922]`）で omega に 0.922 を掛ける。
  v は真値と一致する（x 1.000）ので倍率なし。
- 移動平均 1 と倍率 0.922 で、omega は時刻・傾き・大きさとも真値に合う。

![倍率](dev_log_images/odom_scale_omega.png)

図のデータ：`spin360_w1_ekf`（移動平均 1 で録画）。「移動平均 10」は同じ走行の車輪の回転角から diff_drive_controller と
同じ計算で求めた（変更前の録画で実物と一致することを確認、RMS 0）。描画は `tools/plot_odom_filter.py`
（自己位置推定コンテナ `localizer_rl` の `/root/tools` で実行）。

## 3. LiDAR の向きを 5° 回す（試験のための一時的な変更。2026-10-15、ユーザー指示）

- 目的：取付の yaw のキャリブレーションの試験。LiDAR が設定（TF）より 5° 回って付いている状態を作る。
- 初めに `velodyne_description/urdf/VLP-16.urdf.xacro` の `<sensor>` の `<pose>` の yaw を 5° にしたが、効かなかった（元に戻した）。
  Gazebo は URDF を読むとき固定の関節でつながったリンクを 1 つにまとめ、センサの `<pose>` を取付の位置で上書きするため
  （`gz sdf -p` で変換後のセンサの pose が `-0.17 0 1.1377 0 0 0` になる）。
- 変更：`/root/ros2_ws/src/wheelchair/electric_wheelchair/xacro/wheelchair_2.xacro` の 330 行目（LiDAR の `<origin>`）を
  `rpy="0 0 0"` → `rpy="0 0 ${0.0872665 if '$(arg for_gazebo)' == 'true' else 0}"`。元は同じ場所の `wheelchair_2.xacro.bak_20261015`。
  - Gazebo に渡すモデル（`for_gazebo: true`）だけ LiDAR が yaw +5° 回る。robot_state_publisher のモデル（`for_gazebo: false`）は 0° のままなので、
    推定器は取付を 0° とみなす（実機で取付がずれているのと同じ）。
  - xacro は Gazebo の起動のたびに読まれる（`gazebo.launch.py` が `wheelchair.urdf` に書き出して spawn）。
- 試験が終わったら元に戻す。
- 2026-10-15：試験（`gazebo_calibration_yaw5`）のあと元に戻した（`wheelchair_2.xacro` は `.bak_20261015` と一致を確かめて、`.bak` を消した。
  `VLP-16.urdf.xacro` も元のまま）。次に Gazebo を起動したときから LiDAR は 0° に戻る。
