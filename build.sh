#!/bin/sh
# Build SprintSplit for one watch model, or for every supported model.
#
#   ./build.sh                 fenix7 のリリースビルド（既定）
#   ./build.sh fr265s          機種を指定してビルド
#   ./build.sh --all           対応する全機種をまとめてビルド
#   ./build.sh fr265s --run    ビルドしてシミュレータで起動
#   ./build.sh fr265s --debug  デバッグ情報つきでビルド（開発時向け）
#   ./build.sh --list          対応機種の一覧を表示
#
# 生成物は bin/SprintSplit_<機種ID>.prg に出ます。
# 署名鍵はリポジトリ外の ~/.garmin-keys に置きます（GARMIN_KEY_DIR で変更可）。
# 詳しい手順とトラブルシューティングは BUILD.md を参照してください。
set -e

cd "$(dirname "$0")"

DEVICE=""
BUILD_ALL="no"
RUN_SIM="no"
RELEASE="-r"

# The manifest is the single source of truth for which models are supported.
supported_devices() {
    sed -n 's/.*<iq:product id="\([^"]*\)".*/\1/p' manifest.xml
}

for arg in "$@"; do
    case "$arg" in
        --list)
            echo "対応機種ID（manifest.xml より）:"
            supported_devices | sed 's/^/  /'
            exit 0
            ;;
        --all)
            BUILD_ALL="yes"
            ;;
        --run)
            RUN_SIM="yes"
            ;;
        --debug)
            RELEASE=""
            ;;
        -*)
            echo "不明なオプション: $arg" >&2
            echo "使い方: ./build.sh [機種ID | --all] [--run] [--debug] [--list]" >&2
            exit 1
            ;;
        *)
            DEVICE="$arg"
            ;;
    esac
done

if [ -z "$DEVICE" ]; then
    DEVICE="fenix7"
fi

# The SDK path comes from the SDK Manager's config file; the env var wins so a
# second SDK can be used without touching the config.
if [ -z "$SDKROOT" ]; then
    if [ -f "$HOME/.Garmin/ConnectIQ/current-sdk.cfg" ]; then
        SDKROOT=$(tr -d '\n' < "$HOME/.Garmin/ConnectIQ/current-sdk.cfg")
    elif command -v connect-iq-sdk-manager > /dev/null 2>&1; then
        SDKROOT=$(connect-iq-sdk-manager sdk current-path)
    fi
fi

if [ ! -x "$SDKROOT/bin/monkeyc" ]; then
    echo "Connect IQ SDK が見つかりません。" >&2
    echo "SDK Manager で SDK を取得するか、SDKROOT にSDKのパスを設定してください:" >&2
    echo "  SDKROOT=/path/to/connectiq-sdk ./build.sh $DEVICE" >&2
    exit 1
fi

# Every developer signs with their own key; never share or commit it. The key
# lives outside the repository so it can never be picked up by `git add`.
KEY_DIR="${GARMIN_KEY_DIR:-$HOME/.garmin-keys}"
KEY_PEM="$KEY_DIR/developer_key.pem"
KEY_DER="$KEY_DIR/developer_key.der"

if [ ! -f "$KEY_DER" ]; then
    echo "署名鍵が無いので作成します ($KEY_DER)"
    mkdir -p "$KEY_DIR"
    chmod 700 "$KEY_DIR"
    (
        umask 077
        openssl genrsa -out "$KEY_PEM" 4096
        openssl pkcs8 -topk8 -inform PEM -outform DER \
            -in "$KEY_PEM" -out "$KEY_DER" -nocrypt
    )
fi

build_one() {
    device="$1"
    output="bin/SprintSplit_$device.prg"
    echo "ビルド中: $device -> $output"
    # shellcheck disable=SC2086  # $RELEASE is an intentional word split
    "$SDKROOT/bin/monkeyc" -f monkey.jungle -d "$device" -o "$output" \
        -y "$KEY_DER" $RELEASE
}

if [ "$BUILD_ALL" = "yes" ]; then
    failed=""
    built=0
    for device in $(supported_devices); do
        if build_one "$device"; then
            built=$((built + 1))
        else
            failed="$failed $device"
        fi
    done

    echo ""
    echo "成功: $built 機種"
    if [ -n "$failed" ]; then
        echo "失敗:$failed" >&2
        echo "→ SDK Manager の Devices タブで、その機種のデバイスファイルを取得してください" >&2
        exit 1
    fi
    echo "生成物は bin/ にあります"
    exit 0
fi

build_one "$DEVICE"
echo "完了: bin/SprintSplit_$DEVICE.prg"

if [ "$RUN_SIM" = "yes" ]; then
    # The simulator has to be up before monkeydo can hand it the app.
    if ! pgrep -f "MacOS/simulator" > /dev/null 2>&1; then
        echo "シミュレータを起動しています..."
        "$SDKROOT/bin/connectiq" &
        sleep 15
    fi
    echo "シミュレータでアプリを起動します (終了は Ctrl+C)"
    "$SDKROOT/bin/monkeydo" "bin/SprintSplit_$DEVICE.prg" "$DEVICE"
fi
