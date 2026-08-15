import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Numeric wheel used for every "how many seconds" prompt on the watch.
//
// This is drawn by hand rather than built on WatchUi.Picker: the system picker
// paints its own chrome in the device's UI personality (white on fenix7), which
// clashes with the black pages of the rest of the app. Drawing it here also
// lets the value carry its "s" unit — the number font has digits only, so the
// unit is drawn separately in a text font.
class SecondsPicker extends WatchUi.View {
    private var _title as String;
    private var _value as Number;
    private var _min as Number;
    private var _max as Number;

    // Holding UP or DOWN steps faster the longer you keep going, so a 600s
    // split is reachable without hundreds of presses.
    private var _lastStepMs as Number = 0;
    private var _lastDirection as Number = 0;
    private var _repeatCount as Number = 0;

    public function initialize(titleText as String, current as Number,
                               start as Number, stop as Number) {
        View.initialize();
        _title = titleText;
        _min = start;
        _max = stop;
        _value = clamp(current);
    }

    public function getValue() as Number {
        return _value;
    }

    private function clamp(value as Number) as Number {
        if (value < _min) {
            return _min;
        }
        if (value > _max) {
            return _max;
        }
        return value;
    }

    // direction is +1 or -1; repeated presses in the same direction accelerate
    public function bump(direction as Number) as Void {
        var now = System.getTimer();
        if (direction == _lastDirection && now - _lastStepMs < 400) {
            _repeatCount += 1;
        } else {
            _repeatCount = 0;
        }
        _lastDirection = direction;
        _lastStepMs = now;

        var step = 1;
        if (_repeatCount >= 8) {
            step = 10;
        } else if (_repeatCount >= 4) {
            step = 5;
        }

        _value = clamp(_value + direction * step);
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Theme.TEXT, Theme.BG);
        dc.clear();
        PageChrome.header(dc, _title);

        var w = dc.getWidth();
        var h = dc.getHeight();
        var centerY = (h * 0.44).toNumber();

        // "31" in the number font, with the unit beside it in a text font
        var numberFont = Graphics.FONT_NUMBER_MEDIUM;
        var unitFont = Graphics.FONT_SMALL;
        var text = _value.toString();
        var numberWidth = dc.getTextWidthInPixels(text, numberFont);
        var unitWidth = dc.getTextWidthInPixels("s", unitFont);
        var gap = 6;
        var startX = w / 2 - (numberWidth + gap + unitWidth) / 2;

        dc.setColor(Theme.ACCENT_SOFT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX, centerY, numberFont, text,
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // sit the unit on the number's baseline rather than its centre
        var unitY = centerY + (dc.getFontHeight(numberFont) - dc.getFontHeight(unitFont)) / 4;
        dc.setColor(Theme.TEXT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(startX + numberWidth + gap, unitY, unitFont, "s",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);

        // which way the buttons move the value
        PageChrome.centered(dc, 0.295, atMax() ? "" : "+", Graphics.FONT_SMALL, Theme.ACCENT_DIM);
        PageChrome.centered(dc, 0.585, atMin() ? "" : "-", Graphics.FONT_SMALL, Theme.ACCENT_DIM);

        PageChrome.rule(dc, 0.665, 0.6);
        PageChrome.centered(dc, 0.725, "UP / DOWN = CHANGE",
            Graphics.FONT_XTINY, Theme.TEXT_DIM);
        PageChrome.centered(dc, 0.795, "START = OK",
            Graphics.FONT_XTINY, Theme.ACCENT);
        PageChrome.centered(dc, 0.865, "BACK = CANCEL",
            Graphics.FONT_XTINY, Theme.ACCENT_DIM);
    }

    private function atMin() as Boolean {
        return _value <= _min;
    }

    private function atMax() as Boolean {
        return _value >= _max;
    }
}

// What the picked value should be applied to. `index` is the split being
// edited when mode is :editSplit.
class SecondsPickerDelegate extends WatchUi.BehaviorDelegate {
    private var _picker as SecondsPicker;
    private var _store as SplitStore;
    private var _mode as Symbol;
    private var _index as Number;
    private var _onDone as Method() as Void;

    public function initialize(picker as SecondsPicker, store as SplitStore, mode as Symbol,
                               index as Number, onDone as Method() as Void) {
        BehaviorDelegate.initialize();
        _picker = picker;
        _store = store;
        _mode = mode;
        _index = index;
        _onDone = onDone;
    }

    // UP on a button watch, swipe down on a touch one
    public function onPreviousPage() as Boolean {
        _picker.bump(1);
        return true;
    }

    public function onNextPage() as Boolean {
        _picker.bump(-1);
        return true;
    }

    // touch-only watches have no UP/DOWN keys: tapping above or below the
    // value does the same job
    public function onTap(event as WatchUi.ClickEvent) as Boolean {
        var coordinates = event.getCoordinates();
        var height = System.getDeviceSettings().screenHeight;
        _picker.bump(coordinates[1] < height / 2 ? 1 : -1);
        return true;
    }

    public function onSelect() as Boolean {
        var picked = _picker.getValue();
        if (_mode == :addSplit) {
            _store.addSplit(picked);
        } else if (_mode == :editSplit) {
            _store.setSplitAt(_index, picked);
        } else if (_mode == :delaySeconds) {
            _store.setDelaySeconds(picked);
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _onDone.invoke();
        return true;
    }

    public function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
