import Toybox.WatchUi;
import Toybox.System;
import Toybox.Lang;

// Input for all four carousel pages. UP/DOWN scroll between them, Select
// drives the split sub feature, Menu opens settings, Back ends the run.
class PageDelegate extends WatchUi.BehaviorDelegate {
    private var _recorder as ActivityRecorder;
    private var _tracker as SplitTracker;
    private var _store as SplitStore;
    private var _pageIndex as Number;

    public function initialize(recorder as ActivityRecorder, tracker as SplitTracker,
                               store as SplitStore, pageIndex as Number) {
        BehaviorDelegate.initialize();
        _recorder = recorder;
        _tracker = tracker;
        _store = store;
        _pageIndex = pageIndex;
    }

    public static function viewFor(index as Number, recorder as ActivityRecorder,
                                   tracker as SplitTracker,
                                   store as SplitStore) as WatchUi.View {
        if (index == 1) {
            return new SplitView(recorder, tracker, store);
        }
        if (index == 2) {
            return new SpeedCurveView(recorder, tracker, store);
        }
        if (index == 3) {
            return new ClockView(recorder, tracker, store);
        }
        return new RunView(recorder, tracker, store);
    }

    public function onSelect() as Boolean {
        _tracker.toggle(_recorder.getElapsedMs());
        // jump to the split page so the rep clock is visible right away
        if (_pageIndex != 1) {
            goToPage(1, WatchUi.SLIDE_LEFT);
        } else {
            WatchUi.requestUpdate();
        }
        return true;
    }

    public function onNextPage() as Boolean {
        goToPage((_pageIndex + 1) % PageChrome.PAGE_COUNT, WatchUi.SLIDE_UP);
        return true;
    }

    public function onPreviousPage() as Boolean {
        goToPage((_pageIndex + PageChrome.PAGE_COUNT - 1) % PageChrome.PAGE_COUNT,
            WatchUi.SLIDE_DOWN);
        return true;
    }

    private function goToPage(index as Number, transition as WatchUi.SlideType) as Void {
        WatchUi.switchToView(
            viewFor(index, _recorder, _tracker, _store),
            new PageDelegate(_recorder, _tracker, _store, index),
            transition);
    }

    public function onMenu() as Boolean {
        var menu = MainMenuDelegate.build(_store);
        WatchUi.pushView(menu,
            new MainMenuDelegate(_recorder, _tracker, _store, menu), WatchUi.SLIDE_UP);
        return true;
    }

    public function onBack() as Boolean {
        var menu = EndRunMenuDelegate.build();
        WatchUi.pushView(menu, new EndRunMenuDelegate(_recorder), WatchUi.SLIDE_UP);
        return true;
    }
}

// Ending a run offers three ways out: keep it, throw it away, or go back to the
// run. Backing out of this menu is the cancel path, so it needs no item.
class EndRunMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _recorder as ActivityRecorder;

    public static function build() as WatchUi.Menu2 {
        var menu = new WatchUi.Menu2({:title => "END RUN"});
        menu.addItem(new WatchUi.MenuItem("Save run", "sync to Garmin Connect",
            :save, null));
        menu.addItem(new WatchUi.MenuItem("Discard run", "delete without saving",
            :discard, null));
        menu.addItem(new WatchUi.MenuItem("Cancel", "keep running", :cancel, null));
        return menu;
    }

    public function initialize(recorder as ActivityRecorder) {
        Menu2InputDelegate.initialize();
        _recorder = recorder;
    }

    public function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();

        if (id == :save) {
            _recorder.stopAndSave();
            System.exit();

        } else if (id == :discard) {
            DiscardConfirmationDelegate.prompt(_recorder);

        } else if (id == :cancel) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}

// Discarding cannot be undone, so it always goes through a confirmation that
// starts on "No".
class DiscardConfirmationDelegate extends WatchUi.ConfirmationDelegate {
    private var _recorder as ActivityRecorder;

    public static function prompt(recorder as ActivityRecorder) as Void {
        WatchUi.pushView(new WatchUi.Confirmation("Discard run?"),
            new DiscardConfirmationDelegate(recorder), WatchUi.SLIDE_IMMEDIATE);
    }

    public function initialize(recorder as ActivityRecorder) {
        ConfirmationDelegate.initialize();
        _recorder = recorder;
    }

    public function onResponse(response as WatchUi.Confirm) as Boolean {
        if (response == WatchUi.CONFIRM_YES) {
            _recorder.stopAndDiscard();
            System.exit();
        }
        return true;
    }
}
