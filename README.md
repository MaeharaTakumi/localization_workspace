# localization_workspace

車椅子（WHILL）の自己位置推定（NDT + EKF、ROS 2 Humble、Docker）の作業場所。開発ログ・作業の決まり・リポジトリの一覧を管理する。
プログラムは別々のリポジトリで、ここには入れていない（`.gitignore` で外す）。

| ファイル・フォルダ | 中身 |
|---|---|
| `dev_log.md` | 開発ログ（目的・やったこと・結果・図） |
| `dev_log_images/` | 開発ログ・`gazebo_changes.md` に埋め込む図 |
| `gazebo_changes.md` | Gazebo のコンテナに加えた変更の記録 |
| `CLAUDE.md` | 作業の決まりと構成（Claude Code 用） |
| `repos.yaml`・`clone_repos.sh` | 中に置くリポジトリの一覧と、それを clone するスクリプト |
| `deploy.sh` | `src/` のリポジトリを自己位置推定のコンテナ `test` に写してビルドする（下記） |

```bash
git clone git@github.com:MaeharaTakumi/localization_workspace.git localization
cd localization && ./clone_repos.sh      # docker/（localizer_docker）と src/ の各リポジトリ
```

コンテナの作り方・コマンドは `docker/README.md`、検証のプログラムは `src/localization_tools/README.md`。

## コンテナへの反映

`src/` のリポジトリを変えたら、コンテナで何かを実行する前に `deploy.sh` で反映する（ホストで実行）。

```bash
./deploy.sh                           # 全部（ROS のパッケージ 4 つをビルド、localization_tools は写すだけ）
./deploy.sh ekf_localizer             # 指定したリポジトリだけ（複数書ける）
./deploy.sh --test ekf_localizer      # ビルドのあと colcon test も
./deploy.sh --mirror localization_bringup   # コンテナ側を消してから写す（ホストで消した・名前を変えたファイルを残さない）
```
