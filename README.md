# dataset-area-stats

Queria のデータセット `area_stats`（地域ごとの指標）のリポジトリです。データセットの説明は [docs/index.md](docs/index.md) にあります。

## ビルド

毎月 3 日に `Sync` のワークフローが作り直して公開します。手元で実行するときは次のとおりです。

```bash
uv sync
FDL_TOKEN=... scripts/build.sh
```
