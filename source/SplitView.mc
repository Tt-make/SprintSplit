import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// Page 2: the interval/split sub feature. Select starts and stops it; the
// segment strip shows how far through the configured splits this rep is.
class SplitView extends PageView {

    public function initialize(recorder as ActivityRecorder, tracker as SplitTracker,
                               store as SplitStore) {
        PageView.initialize(recorder, tracker, store, 1);
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        // the header carries the preset in use so the set being run is never
        // in doubt at the start line
        beginFrame(dc, "SPLITS  " + _tracker.getPresetLabel());

        var statusColor = _tracker.isRunning() ? Theme.ACCENT_SOFT
            : (_tracker.isCountingDown() ? Theme.ACCENT
            : (_tracker.isDone() ? Theme.ACCENT : Theme.TEXT_DIM));
        PageChrome.centered(dc, 0.265, _tracker.getStatusLabel(),
            Graphics.FONT_SMALL, statusColor);

        PageChrome.rule(dc, 0.345, 0.62);

        // headline: this rep's stopwatch, frozen on the final time once the
        // whole set of splits has been reached
        PageChrome.centered(dc, 0.455, _tracker.getRepElapsedLabel(),
            Graphics.FONT_NUMBER_MEDIUM,
            (_tracker.isRunning() || _tracker.isDone()) ? Theme.ACCENT_SOFT : Theme.TEXT_DIM);

        PageChrome.rule(dc, 0.565, 0.72);

        PageChrome.centered(dc, 0.625, _tracker.getNextSplitLabel(),
            Graphics.FONT_TINY, Theme.TEXT);

        drawProgressStrip(dc, 0.715);

        PageChrome.centered(dc, 0.805, _tracker.getLastSplitLabel(),
            Graphics.FONT_XTINY, Theme.TEXT_DIM);

        PageChrome.centered(dc, 0.872,
            _tracker.isDone() ? "SELECT = NEXT REP" : "SELECT = START/STOP",
            Graphics.FONT_XTINY, Theme.ACCENT_DIM);

        endFrame(dc);
    }

    // One segment per configured split; filled segments are the ones reached.
    private function drawProgressStrip(dc as Graphics.Dc, yFactor as Float) as Void {
        var total = _tracker.getTargetCount();
        if (total == 0) {
            return;
        }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var y = (h * yFactor).toNumber();
        var stripWidth = (w * 0.62).toNumber();
        var gap = 4;
        var segWidth = (stripWidth - gap * (total - 1)) / total;
        if (segWidth < 2) {
            segWidth = 2;
        }
        var startX = w / 2 - (segWidth * total + gap * (total - 1)) / 2;
        var done = _tracker.getAchievedCount();

        for (var i = 0; i < total; i++) {
            var x = startX + (segWidth + gap) * i;
            dc.setColor(i < done ? Theme.ACCENT_SOFT : Theme.ACCENT_DIM,
                Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, segWidth, 6);
        }
    }
}
