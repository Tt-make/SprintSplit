# ビルド手順書（全対応機種）

SprintSplit を対応する **12機種すべて**に向けてビルドし、ウォッチへ入れるまでの手順書です。使い方や機能の説明は [README.md](README.md) を参照してください。

Connect IQアプリの `.prg` ファイルは**機種ごとに別物**です。fēnix 7 用の `.prg` を Forerunner 265S に入れても動きません。使いたい機種の数だけビルドしてください。

---

## 目次

1. [全体の流れ](#1-全体の流れ)
2. [必要なもの](#2-必要なもの)
3. [Connect IQ SDK を用意する](#3-connect-iq-sdk-を用意する)
4. [デバイスファイルを取得する（機種ごとに必要）](#4-デバイスファイルを取得する機種ごとに必要)
5. [署名鍵を作る](#5-署名鍵を作る)
6. [ビルドする](#6-ビルドする)
7. [対応機種一覧](#7-対応機種一覧)
8. [ウォッチへ転送する](#8-ウォッチへ転送する)
9. [シミュレータで動作確認する](#9-シミュレータで動作確認する)
10. [トラブルシューティング](#10-トラブルシューティング)
11. [対応機種を追加する](#11-対応機種を追加する)

---

## 1. 全体の流れ

```
SDKを入れる  →  使う機種のデバイスファイルを取得  →  署名鍵を作る
                                                        ↓
        ウォッチの Apps フォルダへコピー  ←  ./build.sh <機種ID>
```

2回目以降は最後の2ステップ（ビルド → コピー）だけです。

---

## 2. 必要なもの

| 必要なもの | 備考 |
|---|---|
| Windows または macOS のパソコン | Linuxでも非公式に可（SDKは公式にはWin/Mac対応） |
| Garmin developer アカウント | [developer.garmin.com](https://developer.garmin.com/) で無料登録 |
| Connect IQ SDK | 次の章で取得します |
| `openssl` | 署名鍵の作成に使用。macOS・Linuxには標準で入っています |
| USBケーブル | ウォッチへ転送するとき（充電ケーブルで可） |

VS Code と拡張機能「[Monkey C](https://marketplace.visualstudio.com/items?itemName=garmin.monkey-c)」を入れると、GUIからビルド・シミュレータ実行もできます（本書はターミナル中心で説明します）。

---

## 3. Connect IQ SDK を用意する

Garmin公式の **[Connect IQ SDK Manager](https://developer.garmin.com/connect-iq/sdk/)** をダウンロードして起動し、

1. Garminアカウントでログイン
2. **SDK** タブで最新のSDKを `Download`
3. ダウンロードしたSDKを **`Set as Current`**（現在使うSDKに設定）

このプロジェクトは `manifest.xml` で `minSdkVersion="4.2.0"` を指定しているため、**SDK 4.2.0 以降**が必要です。

インストール先とパスの記録場所は次の通りです。

| OS | SDK本体 | 現在のSDKパスが書かれたファイル |
|---|---|---|
| macOS / Linux | `~/.Garmin/ConnectIQ/Sdks/` | `~/.Garmin/ConnectIQ/current-sdk.cfg` |
| Windows | `%APPDATA%\Garmin\ConnectIQ\Sdks\` | `%APPDATA%\Garmin\ConnectIQ\current-sdk.cfg` |

`build.sh` はこの `current-sdk.cfg` を自動で読みます。別のSDKを使いたいときは環境変数で上書きできます。

```bash
SDKROOT=/path/to/connectiq-sdk ./build.sh fenix7
```

---

## 4. デバイスファイルを取得する（機種ごとに必要）

**ここが一番つまずきやすい箇所です。** SDK本体だけではビルドできず、**機種ごとの「デバイスファイル」**が別途必要です。

SDK Manager の **Devices** タブを開き、ビルドしたい機種（fēnix 7、Forerunner 265s、Venu 3 など）にチェックを入れて `Download` してください。全機種向けにビルドするなら、[対応機種一覧](#7-対応機種一覧)の12機種すべてを取得します。

取得済みの機種は次のコマンドで確認できます（macOS / Linux）。

```bash
ls ~/.Garmin/ConnectIQ/Devices
```

ここに機種IDが並んでいればビルドできます。未取得の機種を指定すると `ERROR: Invalid device id specified: 'xxx'.` というエラーになります。

---

## 5. 署名鍵を作る

Connect IQアプリのビルドには、開発者ごとの署名鍵が必要です。**`build.sh` は鍵が無ければ自動で作成する**ので、通常この章の操作は不要です。

鍵は**リポジトリの外**（既定では `~/.garmin-keys/`）に作られます。こうしておけば、`git add` や `.gitignore` の編集ミスでリポジトリに紛れ込むことがありません。手動で作る場合は:

```bash
mkdir -p ~/.garmin-keys && chmod 700 ~/.garmin-keys && (umask 077 && openssl genrsa -out ~/.garmin-keys/developer_key.pem 4096 && openssl pkcs8 -topk8 -inform PEM -outform DER -in ~/.garmin-keys/developer_key.pem -out ~/.garmin-keys/developer_key.der -nocrypt)
```

別の場所に置きたい場合は `GARMIN_KEY_DIR` で指定できます:

```bash
GARMIN_KEY_DIR=/path/to/keys ./build.sh fr265s
```

> **注意**
> - 鍵は**自分専用**です。他人と共有したり、GitHubに公開したりしないでください（リポジトリ外に置いたうえで、[.gitignore](.gitignore) でも二重に除外しています）
> - 同じ鍵でビルドしたアプリは「同じ開発者のアプリ」として扱われます。**鍵を作り直すと別アプリ扱いになり、ウォッチ内の設定が引き継がれません**。一度作った鍵は保管しておいてください
> - 全機種分をビルドするときも、鍵は**1つを使い回します**（機種ごとに作る必要はありません）

---

## 6. ビルドする

### 1機種だけビルドする

```bash
./build.sh fr265s
```

`bin/SprintSplit_fr265s.prg` が生成されます。機種IDは[対応機種一覧](#7-対応機種一覧)を参照してください。引数を省略すると `fenix7` になります。

### 対応する全機種をまとめてビルドする

```bash
./build.sh --all
```

`manifest.xml` に書かれた全機種を順にビルドし、最後に成功数と失敗した機種を表示します。失敗した機種は、たいていデバイスファイルが未取得です（[第4章](#4-デバイスファイルを取得する機種ごとに必要)）。

### そのほかのオプション

| コマンド | 動作 |
|---|---|
| `./build.sh --list` | 対応機種IDの一覧を表示（`manifest.xml` から自動生成） |
| `./build.sh fr265s --run` | ビルドしてシミュレータで起動 |
| `./build.sh fr265s --debug` | デバッグ情報つきでビルド（開発時向け。既定はリリースビルド） |

### スクリプトを使わずビルドする

```bash
SDKROOT=$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg) && "$SDKROOT/bin/monkeyc" -f monkey.jungle -d fr265s -o bin/SprintSplit_fr265s.prg -y ~/.garmin-keys/developer_key.der -r
```

`-d` の値を変えれば他の機種になります。`-r` はリリースビルドの指定です。

---

## 7. 対応機種一覧

`manifest.xml` に登録済みの12機種です。「出力サイズ」はビルド後の `.prg` のおおよそのサイズで、動作確認の目安になります。

| 機種ID | 製品名 | 画面 | 画面種別 | 出力サイズ |
|---|---|---|---|---|
| `fenix7` | fēnix 7 / quatix 7 | 260×260 | MIP | 約24 KB |
| `fenix7s` | fēnix 7S | 240×240 | MIP | 約24 KB |
| `fenix7x` | fēnix 7X / tactix 7 / Enduro 2 | 280×280 | MIP | 約24 KB |
| `fr255` | Forerunner 255 | 260×260 | MIP | 約24 KB |
| `fr255s` | Forerunner 255s | 218×218 | MIP | 約24 KB |
| `fr265` | Forerunner 265 | 416×416 | AMOLED | 約30 KB |
| `fr265s` | Forerunner 265s | 360×360 | AMOLED | 約30 KB |
| `fr965` | Forerunner 965 | 454×454 | AMOLED | 約33 KB |
| `venu2` | Venu 2 | 416×416 | AMOLED | 約34 KB |
| `venu3` | Venu 3 | 454×454 | AMOLED | 約34 KB |
| `venu3s` | Venu 3S | 390×390 | AMOLED | 約34 KB |
| `epix2` | epix (Gen 2) / quatix 7 Sapphire | 416×416 | AMOLED | 約30 KB |

画面のレイアウトは画面サイズに対する**比率**で指定しているため、218×218 から 454×454 まで同じコードで破綻せずに表示されます。

MIP機種（fēnix 7 / Forerunner 255）は**64色パレット**で描画されるため、色は近いパレット色に丸められます。配色を変えるときは [source/Theme.mc](source/Theme.mc) の説明も参照してください。

---

## 8. ウォッチへ転送する

1. ウォッチをUSBでパソコンに接続します
2. ウォッチのストレージを開き、`GARMIN` → **`Apps`** フォルダ（機種により `APPS` 表記）を開きます。無ければ `Apps` という名前で作成します
3. ビルドした **その機種用の** `.prg` を `Apps` フォルダの**直下**にコピーします（`DATA` や `SETTINGS` などのサブフォルダには入れません）
4. ウォッチを安全に取り外します（macOSはドライブを「取り出す」、Windowsは「ハードウェアの安全な取り外し」）
5. ウォッチのアプリ一覧に **SprintSplit** が現れます（出ない場合は一度ウォッチを再起動）

**接続方式の違い**

| 接続方式 | 該当機種の例 | 見え方 |
|---|---|---|
| MSC（USBマスストレージ） | fēnix 7 シリーズなど | 通常の外部ドライブとしてマウントされる |
| MTP | Forerunner 265 / Venu 3 など新しめの機種 | macOSではFinderに出ないため、[Android File Transfer](https://www.android.com/filetransfer/) などのMTP対応ソフトが必要。Windowsはエクスプローラーでそのまま開けます |

複数の機種に入れる場合も、**それぞれの機種用にビルドした `.prg`** を各ウォッチにコピーしてください。ファイル名は自由ですが、`SprintSplit_fr265s.prg` のように機種IDが入ったままにしておくと取り違えを防げます。

---

## 9. シミュレータで動作確認する

ウォッチが無くても、パソコン上のシミュレータで全機種の表示を確認できます。

```bash
./build.sh fr265s --run
```

手動で行う場合は、シミュレータを起動してから `monkeydo` でアプリを送り込みます（**順番が逆だと `Unable to connect to simulator.` になります**）。

```bash
"$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg)/bin/connectiq"
```

```bash
SDKROOT=$(cat ~/.Garmin/ConnectIQ/current-sdk.cfg) && "$SDKROOT/bin/monkeydo" bin/SprintSplit_fr265s.prg fr265s
```

**シミュレータでの操作**

- ウォッチ画像の左右にあるボタンをマウスでクリックします
- **UP / DOWN**：ページ切り替え（RUN → SPLITS → SPEED CURVE → TIME）
- **START**：スプリット計測の開始／中止、決定、および1本完了後に次の1本を開始
- **BACK**：戻る／ラン終了
- **UPを長押し**：MENU（Preset、Split seconds、Alerts、Delayed start など）
- 速度・心拍は実データが無いと0のままです。**Simulation** メニューのアクティビティデータ再生機能を使うと、速度やグラフの動きも確認できます
- スプリット秒数を短く（例：`3,6,9`）しておくと、1本の完了 → スピードカーブへの自動切替 → 次の1本、という流れを短時間で確認できます
- シミュレータでは音やバイブは鳴りません。通知そのものの確認は実機で行ってください

---

## 10. トラブルシューティング

| 症状・エラー | 原因 | 対処 |
|---|---|---|
| `ERROR: Invalid device id specified: 'xxx'.` | その機種のデバイスファイルが未取得、または機種IDの綴り違い | SDK Manager の Devices タブで取得。IDは `./build.sh --list` で確認 |
| `Connect IQ SDK が見つかりません。` | SDKが未インストール、または `Set as Current` にしていない | SDK Manager でSDKを取得し現在のSDKに設定。または `SDKROOT=...` を指定 |
| `Unable to connect to simulator.` | シミュレータが起動していない／落ちている | 先にシミュレータを起動し、ウォッチの絵が出てから `monkeydo`。残骸のウィンドウは閉じる |
| `WARNING: ... launcher icon (60x60) isn't compatible ...` | ランチャーアイコンが機種の規定サイズと違う | **無害です**。アイコンは自動で縮小されます。気になる場合は機種別のアイコンを用意します |
| `ERROR: Permission 'xxx' required for ...` | `manifest.xml` の権限不足 | `<iq:permissions>` に該当の権限を追加 |
| ウォッチのアプリ一覧に出てこない | 別機種用の `.prg`／`Apps` 直下に無い／拡張子が変わっている | その機種でビルドし直す。コピー先とファイル名（`.prg`）を確認 |
| 起動直後に落ちる・真っ白になる | 古い `.prg` が残っている、SDKと機種の組み合わせ | `Apps` 内の古いファイルを消してから入れ直す |
| Garmin Connect Mobileのアプリ一覧にSprintSplitが出ない・設定画面が開けない | 正常な挙動。サイドロードしたアプリはConnect IQストア経由ではないため、スマホ側の「インストール済みアプリ」一覧・設定画面には出ません | 設定はすべて時計の MENU から行う（README の「[設定](../README.md#設定プリセットスプリット秒数ディレイスタート)」参照）。アクティビティの同期自体は通常通り行われます |
| 画面の文字が□（豆腐）になる | 英数字以外の文字を描画した | 画面表示はASCIIのみ。日本語は設定画面（`resources/strings`）だけで使用 |
| 実機で音が鳴らない／振動しない | アプリの `Alerts` 設定、またはウォッチ本体のトーン・バイブ設定 | MENU → `Alerts` で `sound + vibrate` を選ぶ。ウォッチ本体の「サウンドとバイブレーション」設定も確認 |

---

## 11. 対応機種を追加する

一覧に無い機種でも、Connect IQ 対応であれば追加できます。

1. 機種IDを調べます。SDK Manager の Devices タブの一覧、または取得済みなら次のコマンドで確認できます

```bash
ls ~/.Garmin/ConnectIQ/Devices
```

2. [manifest.xml](manifest.xml) の `<iq:products>` に1行追加します

```xml
<iq:product id="fenix8solar47mm"/>
```

3. SDK Manager でその機種のデバイスファイルを取得します
4. ビルドします

```bash
./build.sh fenix8solar47mm
```

追加した機種は `./build.sh --all` の対象にも自動的に含まれます（`manifest.xml` を読んでいるため）。

なお、このアプリは **API Level 4.2.0 以上・丸型画面**を前提にレイアウトしています。角型画面（Venu Sq など）や極端に小さい画面の機種では、表示位置の調整が必要になる場合があります。
