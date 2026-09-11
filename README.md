# Misete / 見せて

iPadの「画面ミラーリング」から接続し、Macアプリ内で画面を共有するための
ローカルAirPlay受信アプリです。まずmacOS版を開発し、Linux向けに受信処理と
画面表示を分離しています。

## 開発環境の準備

macOS 14以降、Xcode Command Line Tools、Homebrewが必要です。初回だけ次を実行
します。不足するHomebrewパッケージを導入します。依存関係の更新が発生する場合があります。

```sh
scripts/setup.sh
scripts/setup-receiver.sh
```

`setup-receiver.sh` は [UxPlay](https://github.com/FDH2/UxPlay) の
`9bebe1268671aeb76d0fd0e10621c05b5175505e` を `.deps` に取得してビルドします。
同じリビジョンを確認してから毎回ビルドするため、再実行できます。

```sh
scripts/check.sh
scripts/smoke-receiver.py
scripts/build-app.sh
open dist/Misete.app
```

`dist/Misete.app` はローカル開発用です。UxPlay と GStreamer などのHomebrew動的
ライブラリを利用するため、他のMacへコピーして配布できる自己完結型アプリではありません。
アプリには、ビルドしたUxPlayのGPLライセンスと取得元・リビジョンの記録を同梱します。

## iPadから接続する

1. MacとiPadを同じLANに接続し、Miseteを起動して「AirPlayを開始」を押します。
2. iPadでコントロールセンターを開き、「画面ミラーリング」を選びます。
3. 表示された「Misete」を選びます。パスワードや接続コードの入力は不要です。

「接続コード」はデフォルトでオフです。必要な場合だけ、停止中にオンにできます。
同じLAN上の端末はコードなしで接続できます。以前のパスワード入力画面が残っている場合は、
いったんキャンセルして「Misete」を選び直してください。

iPadに専用アプリを入れる必要はありません。AirPlayの検出にはBonjour/mDNSを利用します。
ネットワークやファイアウォールで制限している場合は、mDNSのUDP 5353と、UxPlay用の
TCP/UDPポート35000〜35002を同一LAN内で許可してください。保護された映像コンテンツは
ミラーリングできない場合があります。

## トラブルシューティング

- 「Misete」がiPadに表示されない場合は、両端末が同じLANか、VPNやゲストWi-Fiが
  Bonjour/mDNSを遮断していないかを確認します。
- `scripts/setup-receiver.sh` が依存関係不足で止まる場合は、先に `scripts/setup.sh` を
  実行します。Xcode Command Line Toolsの要求が出た場合は `xcode-select --install` を実行します。
- 起動直後に受信できない場合は、ローカルファイアウォールでポート35000〜35002とUDP 5353を
  許可してください。

`scripts/check.sh` と `scripts/smoke-receiver.py` の合成フレーム・プロセスのテストは、
Swift側の画像デコードや状態管理、ローカルJPEG経路、UxPlayの起動を確認するものです。実際のiPadによる
発見、ペアリング、動画表示を証明するものではありません。実機確認の手順と現在の記録は
[docs/testing.md](docs/testing.md) を参照してください。
