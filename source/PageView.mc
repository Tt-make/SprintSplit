import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;

// Base for the four carousel pages. Every page drives the same 200ms tick, so
// the run clock and the split logic keep advancing no matter which page is up.
class PageView extends WatchUi.View {
    protected var _recorder as ActivityRecorder;
    protected var _tracker as SplitTracker;
    protected var _store as SplitStore;
    protected var _pageIndex as Number;
    private var _uiTimer as Timer.Timer?;

    public function initialize(recorder as ActivityRecorder, tracker as SplitTracker,
                               store as SplitStore, pageIndex as Number) {
        View.initialize();
        _recorder = recorder;
        _tracker = tracker;
        _store = store;
        _pageIndex = pageIndex;
    }

    public function onShow() as Void {
        _uiTimer = new Timer.Timer();
        _uiTimer.start(method(:onTick), 200, true);
    }

    public function onHide() as Void {
        if (_uiTimer != null) {
            _uiTimer.stop();
            _uiTimer = null;
        }
    }

    public function onTick() as Void {
        _recorder.update();
        _tracker.update(_recorder.getElapsedMs(), _recorder.getSpeedMps());

        // A rep that has just run out of splits stops itself; show the result
        // straight away rather than making the runner scroll to it.
        if (_tracker.takeJustFinished() && _pageIndex != SPEED_CURVE_PAGE) {
            WatchUi.switchToView(
                PageDelegate.viewFor(SPEED_CURVE_PAGE, _recorder, _tracker, _store),
                new PageDelegate(_recorder, _tracker, _store, SPEED_CURVE_PAGE),
                WatchUi.SLIDE_LEFT);
            return;
        }

        WatchUi.requestUpdate();
    }

    protected function beginFrame(dc as Graphics.Dc, title as String) as Void {
        dc.setColor(Theme.TEXT, Theme.BG);
        dc.clear();
        PageChrome.header(dc, title);
    }

    protected function endFrame(dc as Graphics.Dc) as Void {
        PageChrome.pageDots(dc, _pageIndex);
    }
}

const SPEED_CURVE_PAGE = 2;
