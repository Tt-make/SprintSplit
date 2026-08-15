import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// Page 3: the speed of the rep, sampled once a second, plotted as a curve. The
// app switches to this page by itself the moment a rep completes its last
// split.
//
// What is on the plot:
//   - the rep on screen: one point per second, bright line
//   - the rep before it: same sampling, dim line, for comparison across a set
//   - the peak: dashed line at the fastest speed seen during the rep, since a
//     one-second sample can fall either side of the real maximum
//   - the configured split seconds: faint vertical marks
class SpeedCurveView extends PageView {

    // past this many points the individual samples are too close together to
    // mark, so the curve is drawn as a bare line
    private const MAX_POINT_MARKERS = 14;

    public function initialize(recorder as ActivityRecorder, tracker as SplitTracker,
                               store as SplitStore) {
        PageView.initialize(recorder, tracker, store, 2);
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        beginFrame(dc, "SPEED CURVE");

        var samples = _tracker.getCurveSamples();
        var peakKmh = _tracker.getPeakSpeedMps() * 3.6;

        if (samples.size() == 0) {
            PageChrome.centered(dc, 0.40, "NO SPEED DATA YET",
                Graphics.FONT_TINY, Theme.TEXT_DIM);
            PageChrome.rule(dc, 0.48, 0.4);
            // the peak is live from the first moment of a rep, so it is worth
            // showing even before the first second has elapsed
            PageChrome.centered(dc, 0.555, "MAX SPEED km/h",
                Graphics.FONT_XTINY, Theme.TEXT_DIM);
            PageChrome.centered(dc, 0.645, peakKmh.format("%.1f"),
                Graphics.FONT_NUMBER_MEDIUM, Theme.ACCENT_SOFT);
            PageChrome.centered(dc, 0.80, "RUN A SET FIRST",
                Graphics.FONT_XTINY, Theme.ACCENT_DIM);
            endFrame(dc);
            return;
        }

        var previous = _tracker.getPreviousRep();
        var previousSamples = (previous != null)
            ? previous.samples : ([] as Array<Float>);

        var w = dc.getWidth();
        var h = dc.getHeight();

        // plot area, inset enough to stay clear of the round bezel
        var left = (w * 0.24).toNumber();
        var right = (w * 0.84).toNumber();
        var top = (h * 0.29).toNumber();
        var bottom = (h * 0.70).toNumber();

        var maxKmh = 0.0;
        var minKmh = 9999.0;
        for (var i = 0; i < samples.size(); i++) {
            var v = samples[i] * 3.6;
            if (v > maxKmh) { maxKmh = v; }
            if (v < minKmh) { minKmh = v; }
        }
        // the comparison rep and the peak line share the same scale
        for (var i = 0; i < previousSamples.size(); i++) {
            var v = previousSamples[i] * 3.6;
            if (v > maxKmh) { maxKmh = v; }
            if (v < minKmh) { minKmh = v; }
        }
        if (peakKmh > maxKmh) {
            maxKmh = peakKmh;
        }
        var span = maxKmh - minKmh;
        if (span < 1.0) {
            // a nearly flat series would otherwise amplify noise into a zigzag
            var mid = (maxKmh + minKmh) / 2.0;
            minKmh = mid - 0.5;
            maxKmh = mid + 0.5;
            span = 1.0;
        }

        // grid: mid line plus the two axes
        dc.setColor(Theme.ACCENT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(left, (top + bottom) / 2, right, (top + bottom) / 2);
        dc.setPenWidth(2);
        dc.drawLine(left, bottom, right, bottom);
        dc.drawLine(left, top, left, bottom);

        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left - 6, top, Graphics.FONT_XTINY, maxKmh.format("%.1f"),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(left - 6, bottom, Graphics.FONT_XTINY, minKmh.format("%.1f"),
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        drawSplitMarks(dc, samples.size(), left, right, top, bottom);
        drawPeakLine(dc, left, right, top, bottom, peakKmh, minKmh, span);

        // the rep before this one, dim and without points
        drawSeries(dc, previousSamples, left, right, top, bottom, minKmh, span,
            Theme.ACCENT_DIM, false);
        // the rep on screen
        drawSeries(dc, samples, left, right, top, bottom, minKmh, span,
            Theme.ACCENT, samples.size() <= MAX_POINT_MARKERS);

        // x-axis: the curve runs from the first second to the last
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText(left, bottom + 16, Graphics.FONT_XTINY, "0s",
            Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(right, bottom + 16, Graphics.FONT_XTINY,
            samples.size().toString() + "s",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);

        // which rep this is, and how the set is going
        var repLabel = _tracker.getRepLabel();
        if (!repLabel.equals("")) {
            PageChrome.centered(dc, 0.235, repLabel, Graphics.FONT_XTINY, Theme.ACCENT_SOFT);
        }

        PageChrome.rule(dc, 0.795, 0.56);
        PageChrome.centered(dc, 0.845,
            Lang.format("$1$s   MAX $2$ km/h", [samples.size(), peakKmh.format("%.1f")]),
            Graphics.FONT_XTINY, Theme.TEXT);
        if (_tracker.isDone()) {
            PageChrome.centered(dc, 0.900, "SELECT = NEXT REP",
                Graphics.FONT_XTINY, Theme.ACCENT_DIM);
        }

        endFrame(dc);
    }

    // Sample i is second i+1 of the rep, so the whole series spans 1..count
    // seconds along the x axis.
    private function xForSecond(second as Float, count as Number,
                                left as Number, right as Number) as Number {
        if (count <= 1) {
            return (left + right) / 2;
        }
        var ratio = (second - 1.0) / (count - 1).toFloat();
        if (ratio < 0.0) { ratio = 0.0; }
        if (ratio > 1.0) { ratio = 1.0; }
        return (left + ratio * (right - left)).toNumber();
    }

    // Faint vertical marks where the configured split seconds fall, so the
    // per-second curve still shows the reps' checkpoints.
    private function drawSplitMarks(dc as Graphics.Dc, count as Number, left as Number,
                                    right as Number, top as Number,
                                    bottom as Number) as Void {
        var targets = _tracker.getTargets();
        dc.setColor(Theme.ACCENT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        for (var i = 0; i < targets.size(); i++) {
            var second = targets[i].toFloat();
            if (second < 1.0 || second > count) {
                continue;
            }
            var x = xForSecond(second, count, left, right);
            dc.drawLine(x, top, x, bottom);
        }
    }

    // One polyline per rep. `withPoints` marks the individual samples, which is
    // only readable while the rep is short.
    private function drawSeries(dc as Graphics.Dc, samples as Array<Float>,
                                left as Number, right as Number, top as Number,
                                bottom as Number, minKmh as Float, span as Float,
                                color as Number, withPoints as Boolean) as Void {
        if (samples.size() == 0) {
            return;
        }
        var prevX = 0;
        var prevY = 0;

        for (var i = 0; i < samples.size(); i++) {
            var kmh = samples[i] * 3.6;
            var x = xForSecond((i + 1).toFloat(), samples.size(), left, right);
            var y = (bottom - ((kmh - minKmh) / span) * (bottom - top)).toNumber();

            if (i > 0) {
                dc.setColor(color, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
                dc.drawLine(prevX, prevY, x, y);
            }
            if (withPoints) {
                dc.setColor(Theme.ACCENT_SOFT, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 4);
            }

            prevX = x;
            prevY = y;
        }
    }

    // Dashed line at the fastest speed of the measurement, labelled so it is
    // not mistaken for one of the samples.
    private function drawPeakLine(dc as Graphics.Dc, left as Number, right as Number,
                                  top as Number, bottom as Number, peakKmh as Float,
                                  minKmh as Float, span as Float) as Void {
        if (peakKmh <= 0.0) {
            return;
        }
        var y = (bottom - ((peakKmh - minKmh) / span) * (bottom - top)).toNumber();
        if (y < top) {
            y = top;
        }
        if (y > bottom) {
            return;
        }

        dc.setColor(Theme.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var dash = 6;
        for (var x = left; x < right; x += dash * 2) {
            var end = x + dash;
            if (end > right) {
                end = right;
            }
            dc.drawLine(x, y, end, y);
        }

        dc.setColor(Theme.ACCENT_SOFT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(right + 2, y - 8, Graphics.FONT_XTINY, "MAX",
            Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
