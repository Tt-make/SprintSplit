import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

// Top-level menu reached with the MENU button. Split editing lives entirely on
// the watch here — including which of the three presets is in use — and the
// same values are still editable from the phone.
class MainMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _recorder as ActivityRecorder;
    private var _tracker as SplitTracker;
    private var _store as SplitStore;
    private var _menu as WatchUi.Menu2;

    public static function build(store as SplitStore) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "MENU"});
        menu.addItem(new WatchUi.MenuItem("Preset", store.presetLabel(), :preset, null));
        menu.addItem(new WatchUi.MenuItem("Split seconds", store.toDisplayString(),
            :splits, null));
        menu.addItem(new WatchUi.ToggleMenuItem("Delayed start",
            {:enabled => "on", :disabled => "off"}, :delayToggle,
            store.isDelayEnabled(), null));
        menu.addItem(new WatchUi.MenuItem("Delay length",
            store.getDelaySeconds().toString() + " s", :delayLength, null));
        menu.addItem(new WatchUi.MenuItem("Alerts", store.getAlertLabel(), :alerts, null));
        menu.addItem(new WatchUi.MenuItem("Reset splits", "clear this set's results",
            :reset, null));
        menu.addItem(new WatchUi.MenuItem("Discard run", "exit without saving",
            :discard, null));
        return menu;
    }

    public function initialize(recorder as ActivityRecorder, tracker as SplitTracker,
                               store as SplitStore, menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _recorder = recorder;
        _tracker = tracker;
        _store = store;
        _menu = menu;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :preset) {
            WatchUi.pushView(PresetMenuDelegate.build(_store),
                new PresetMenuDelegate(_store, _tracker, method(:refresh)),
                WatchUi.SLIDE_LEFT);

        } else if (id == :splits) {
            WatchUi.pushView(SplitListMenuDelegate.build(_store),
                new SplitListMenuDelegate(_store, _tracker), WatchUi.SLIDE_LEFT);

        } else if (id == :delayToggle) {
            _store.setDelayEnabled((item as WatchUi.ToggleMenuItem).isEnabled());

        } else if (id == :delayLength) {
            var picker = new SecondsPicker("DELAY SECONDS", _store.getDelaySeconds(), 1, 60);
            WatchUi.pushView(picker,
                new SecondsPickerDelegate(picker, _store, :delaySeconds, 0, method(:refresh)),
                WatchUi.SLIDE_LEFT);

        } else if (id == :alerts) {
            WatchUi.pushView(AlertMenuDelegate.build(_store),
                new AlertMenuDelegate(_store, method(:refresh)), WatchUi.SLIDE_LEFT);

        } else if (id == :reset) {
            _tracker.reset();
            WatchUi.popView(WatchUi.SLIDE_RIGHT);

        } else if (id == :discard) {
            _recorder.stopAndDiscard();
            System.exit();
        }
    }

    // Called after a picker or the preset list commits, so the sub-labels show
    // the new values.
    public function refresh() as Void {
        setSubLabel(:delayLength, _store.getDelaySeconds().toString() + " s");
        setSubLabel(:splits, _store.toDisplayString());
        setSubLabel(:preset, _store.presetLabel());
        setSubLabel(:alerts, _store.getAlertLabel());
        WatchUi.requestUpdate();
    }

    private function setSubLabel(id as Symbol, text as String) as Void {
        var index = _menu.findItemById(id);
        if (index >= 0) {
            var item = _menu.getItem(index);
            if (item != null) {
                item.setSubLabel(text);
            }
        }
    }
}

// The three saved split sets. Selecting one makes it the set the SPLITS page
// runs against; editing its seconds is then done from "Split seconds".
class PresetMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _store as SplitStore;
    private var _tracker as SplitTracker;
    private var _onDone as Method() as Void;

    public static function build(store as SplitStore) as WatchUi.Menu2 {
        var active = store.getActivePreset();
        // opening on the preset in use is what shows the choice made last time
        var menu = new WatchUi.Menu2({:title => "USE PRESET", :focus => active});
        for (var i = 0; i < SplitStore.PRESET_COUNT; i++) {
            // Menu2 rejects checkbox rows, so the set in use is marked in the
            // text itself — ASCII only, so it renders in every watch language
            var inUse = (i == active);
            var label = Lang.format("Preset $1$$2$", [i + 1, inUse ? "  *" : ""]);
            var detail = store.displayStringFor(i);
            menu.addItem(new WatchUi.MenuItem(label,
                inUse ? "IN USE   " + detail : detail, i, null));
        }
        return menu;
    }

    public function initialize(store as SplitStore, tracker as SplitTracker,
                               onDone as Method() as Void) {
        Menu2InputDelegate.initialize();
        _store = store;
        _tracker = tracker;
        _onDone = onDone;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (!(id instanceof Number)) {
            return;
        }
        _store.setActivePreset(id);
        // a half-finished rep belongs to the old set of targets
        _tracker.reset();
        // refresh the menu behind this one, then redraw this list so the mark
        // moves to the row just chosen instead of the menu closing under it
        _onDone.invoke();
        WatchUi.switchToView(build(_store),
            new PresetMenuDelegate(_store, _tracker, _onDone), WatchUi.SLIDE_IMMEDIATE);
    }
}

// How the go/split/finish alerts are delivered. Same one-of-three shape as the
// preset list: the row in use is marked, and picking one applies it at once.
class AlertMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _store as SplitStore;
    private var _onDone as Method() as Void;

    public static function build(store as SplitStore) as WatchUi.Menu2 {
        var active = store.getAlertMode();
        var menu = new WatchUi.Menu2({:title => "ALERTS", :focus => active});
        for (var mode = SplitStore.ALERT_SOUND; mode <= SplitStore.ALERT_BOTH; mode++) {
            var inUse = (mode == active);
            menu.addItem(new WatchUi.MenuItem(
                store.alertLabelFor(mode) + (inUse ? "  *" : ""),
                inUse ? "IN USE" : null,
                mode, null));
        }
        return menu;
    }

    public function initialize(store as SplitStore, onDone as Method() as Void) {
        Menu2InputDelegate.initialize();
        _store = store;
        _onDone = onDone;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (!(id instanceof Number)) {
            return;
        }
        _store.setAlertMode(id);
        _onDone.invoke();
        WatchUi.switchToView(build(_store),
            new AlertMenuDelegate(_store, _onDone), WatchUi.SLIDE_IMMEDIATE);
    }
}

// The active preset's split list: one row per configured second, plus
// add/clear actions.
class SplitListMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _store as SplitStore;
    private var _tracker as SplitTracker;

    public static function build(store as SplitStore) as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({
            :title => Lang.format("SPLITS P$1$", [store.getActivePreset() + 1])
        });
        var splits = store.getSplits();
        for (var i = 0; i < splits.size(); i++) {
            menu.addItem(new WatchUi.MenuItem(
                splits[i].toString() + " s",
                "split " + (i + 1).toString(),
                i, // Number id = index into the list
                null));
        }
        if (!store.isFull()) {
            menu.addItem(new WatchUi.MenuItem("Add split", "up to "
                + SplitStore.MAX_SPLITS.toString(), :add, null));
        }
        if (splits.size() > 0) {
            menu.addItem(new WatchUi.MenuItem("Clear all", "remove every split",
                :clear, null));
        }
        return menu;
    }

    public function initialize(store as SplitStore, tracker as SplitTracker) {
        Menu2InputDelegate.initialize();
        _store = store;
        _tracker = tracker;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id instanceof Number) {
            var splits = _store.getSplits();
            // seeded with the value already stored, so re-opening a split shows
            // what was chosen last time
            var current = (id < splits.size()) ? splits[id] : 10;
            var picker = new SecondsPicker("EDIT SPLIT", current, 1, 600);
            WatchUi.pushView(picker,
                new SecondsPickerDelegate(picker, _store, :editSplit, id, method(:rebuild)),
                WatchUi.SLIDE_LEFT);

        } else if (id == :add) {
            var seed = _store.size() > 0 ? _store.getSplits()[_store.size() - 1] : 13;
            var addPicker = new SecondsPicker("NEW SPLIT", seed, 1, 600);
            WatchUi.pushView(addPicker,
                new SecondsPickerDelegate(addPicker, _store, :addSplit, 0, method(:rebuild)),
                WatchUi.SLIDE_LEFT);

        } else if (id == :clear) {
            _store.clearSplits();
            _tracker.reset();
            rebuild();
        }
    }

    // The row set changes with every edit, so swap in a freshly built menu
    // rather than trying to patch rows in place.
    public function rebuild() as Void {
        _tracker.reset();
        WatchUi.switchToView(build(_store),
            new SplitListMenuDelegate(_store, _tracker), WatchUi.SLIDE_IMMEDIATE);
    }
}
