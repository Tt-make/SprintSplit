import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class SprintSplitApp extends Application.AppBase {
    private var _store as SplitStore?;
    private var _tracker as SplitTracker?;

    public function initialize() {
        AppBase.initialize();
    }

    public function getInitialView() {
        var store = new SplitStore();
        var recorder = new ActivityRecorder();
        var tracker = new SplitTracker(store, recorder);
        _store = store;
        _tracker = tracker;

        // main function: start capturing the run the moment the app opens
        recorder.start();

        return [PageDelegate.viewFor(0, recorder, tracker, store),
                new PageDelegate(recorder, tracker, store, 0)];
    }

    // Phone-side settings edits land here; pull them in so on-watch state agrees.
    public function onSettingsChanged() as Void {
        if (_store != null) {
            _store.load();
        }
        if (_tracker != null) {
            _tracker.reset();
        }
        WatchUi.requestUpdate();
    }
}

function getApp() as SprintSplitApp {
    return Application.getApp() as SprintSplitApp;
}
