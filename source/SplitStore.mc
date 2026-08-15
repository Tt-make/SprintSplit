import Toybox.Lang;
import Toybox.Application;

// Single owner of the split-second presets and the delayed-start settings.
// Three independent presets are kept side by side (e.g. 100m / 200m / 400m
// sets); one of them is active at a time and is what SplitTracker runs against.
// Backed by the same properties the Garmin Connect phone settings write to, so
// on-watch edits and phone edits stay in sync in both directions.
class SplitStore {
    public static const MAX_SPLITS = 12;
    public static const PRESET_COUNT = 3;

    // How the "go" and split alerts are delivered. Sound only is the default:
    // on a track the beep carries, and a wrist buzz is easy to miss mid-stride.
    public static const ALERT_SOUND = 0;
    public static const ALERT_VIBRATE = 1;
    public static const ALERT_BOTH = 2;

    private var _presets as Array<Array<Number> > = [] as Array<Array<Number> >;
    private var _active as Number = 0;
    private var _delayEnabled as Boolean = false;
    private var _delaySeconds as Number = 5;
    private var _alertMode as Number = ALERT_SOUND;

    public function initialize() {
        load();
    }

    public function load() as Void {
        _presets = [] as Array<Array<Number> >;
        for (var i = 0; i < PRESET_COUNT; i++) {
            _presets.add(parseCsv(Application.Properties.getValue(presetKey(i))));
        }

        var active = Application.Properties.getValue("activePreset");
        // stored 1-based so the phone setting reads naturally
        var index = (active instanceof Number) ? active - 1 : 0;
        _active = (index >= 0 && index < PRESET_COUNT) ? index : 0;

        var enabled = Application.Properties.getValue("delayEnabled");
        _delayEnabled = (enabled instanceof Boolean) ? enabled : false;

        var seconds = Application.Properties.getValue("delaySeconds");
        var delay = (seconds instanceof Number) ? seconds : 5;
        _delaySeconds = (delay >= 1) ? delay : 1;

        var alert = Application.Properties.getValue("alertMode");
        _alertMode = (alert instanceof Number && alert >= ALERT_SOUND && alert <= ALERT_BOTH)
            ? alert : ALERT_SOUND;
    }

    private function presetKey(index as Number) as String {
        if (index == 1) {
            return "splitSecondsCsv2";
        }
        if (index == 2) {
            return "splitSecondsCsv3";
        }
        return "splitSecondsCsv";
    }

    private function save() as Void {
        Application.Properties.setValue(presetKey(_active), toCsv());
    }

    private function parseCsv(raw as Object?) as Array<Number> {
        var result = [] as Array<Number>;
        if (!(raw instanceof String) || raw.length() == 0) {
            return result;
        }
        var remaining = raw as String;
        var done = false;
        while (!done) {
            var idx = remaining.find(",");
            var piece = remaining;
            if (idx == null) {
                done = true;
            } else {
                piece = remaining.substring(0, idx) as String;
                remaining = remaining.substring(idx + 1, remaining.length()) as String;
            }
            piece = trimWhitespace(piece);
            if (piece.length() > 0) {
                var value = piece.toNumber();
                if (value != null && value > 0 && result.size() < MAX_SPLITS) {
                    result.add(value);
                }
            }
        }
        return sorted(result);
    }

    public function toCsv() as String {
        var splits = getSplits();
        var out = "";
        for (var i = 0; i < splits.size(); i++) {
            if (i > 0) {
                out += ",";
            }
            out += splits[i].toString();
        }
        return out;
    }

    // Comma-space form for menu sub-labels, truncated so it never overruns the row.
    public function toDisplayString() as String {
        return displayStringFor(_active);
    }

    public function displayStringFor(index as Number) as String {
        var splits = splitsFor(index);
        if (splits.size() == 0) {
            return "none";
        }
        var out = "";
        for (var i = 0; i < splits.size(); i++) {
            if (i > 0) {
                out += ", ";
            }
            if (i == 4) {
                return out + "...";
            }
            out += splits[i].toString();
        }
        return out + " s";
    }

    // "P2: 13, 26, 55" — used as the menu sub-label for the preset row.
    public function presetLabel() as String {
        return Lang.format("P$1$: $2$", [_active + 1, toDisplayString()]);
    }

    private function sorted(values as Array<Number>) as Array<Number> {
        // insertion sort: users enter split seconds in any order, lists are short
        for (var i = 1; i < values.size(); i++) {
            var key = values[i];
            var j = i - 1;
            while (j >= 0 && values[j] > key) {
                values[j + 1] = values[j];
                j -= 1;
            }
            values[j + 1] = key;
        }
        return values;
    }

    private function trimWhitespace(s as String) as String {
        var chars = s.toCharArray();
        var start = 0;
        var end = chars.size() - 1;
        while (start <= end && isSpaceChar(chars[start])) {
            start += 1;
        }
        while (end >= start && isSpaceChar(chars[end])) {
            end -= 1;
        }
        if (start > end) {
            return "";
        }
        return s.substring(start, end + 1) as String;
    }

    private function isSpaceChar(c as Char) as Boolean {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r';
    }

    public function getSplits() as Array<Number> {
        return _presets[_active];
    }

    public function splitsFor(index as Number) as Array<Number> {
        if (index < 0 || index >= _presets.size()) {
            return [] as Array<Number>;
        }
        return _presets[index];
    }

    public function getActivePreset() as Number {
        return _active;
    }

    public function setActivePreset(index as Number) as Void {
        if (index < 0 || index >= PRESET_COUNT || index == _active) {
            return;
        }
        _active = index;
        Application.Properties.setValue("activePreset", _active + 1);
    }

    public function size() as Number {
        return getSplits().size();
    }

    public function isFull() as Boolean {
        return size() >= MAX_SPLITS;
    }

    public function addSplit(seconds as Number) as Void {
        if (isFull() || seconds <= 0) {
            return;
        }
        var splits = getSplits();
        splits.add(seconds);
        _presets[_active] = sorted(splits);
        save();
    }

    public function setSplitAt(index as Number, seconds as Number) as Void {
        var splits = getSplits();
        if (index < 0 || index >= splits.size() || seconds <= 0) {
            return;
        }
        splits[index] = seconds;
        _presets[_active] = sorted(splits);
        save();
    }

    public function removeSplitAt(index as Number) as Void {
        var splits = getSplits();
        if (index < 0 || index >= splits.size()) {
            return;
        }
        var next = [] as Array<Number>;
        for (var i = 0; i < splits.size(); i++) {
            if (i != index) {
                next.add(splits[i]);
            }
        }
        _presets[_active] = next;
        save();
    }

    public function clearSplits() as Void {
        _presets[_active] = [] as Array<Number>;
        save();
    }

    public function isDelayEnabled() as Boolean {
        return _delayEnabled;
    }

    public function setDelayEnabled(enabled as Boolean) as Void {
        _delayEnabled = enabled;
        Application.Properties.setValue("delayEnabled", enabled);
    }

    public function getDelaySeconds() as Number {
        return _delaySeconds;
    }

    public function setDelaySeconds(seconds as Number) as Void {
        _delaySeconds = (seconds >= 1) ? seconds : 1;
        Application.Properties.setValue("delaySeconds", _delaySeconds);
    }

    public function getAlertMode() as Number {
        return _alertMode;
    }

    // Stored straight away, so the choice survives closing the app.
    public function setAlertMode(mode as Number) as Void {
        if (mode < ALERT_SOUND || mode > ALERT_BOTH) {
            return;
        }
        _alertMode = mode;
        Application.Properties.setValue("alertMode", _alertMode);
    }

    public function alertLabelFor(mode as Number) as String {
        if (mode == ALERT_VIBRATE) {
            return "vibrate only";
        }
        if (mode == ALERT_BOTH) {
            return "sound + vibrate";
        }
        return "sound only";
    }

    public function getAlertLabel() as String {
        return alertLabelFor(_alertMode);
    }

    public function isSoundEnabled() as Boolean {
        return _alertMode == ALERT_SOUND || _alertMode == ALERT_BOTH;
    }

    public function isVibrateEnabled() as Boolean {
        return _alertMode == ALERT_VIBRATE || _alertMode == ALERT_BOTH;
    }
}
