import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// Page 4: the time of day, on its own page, so the watch still answers "what
// time is it" without leaving the run. Recording keeps running underneath —
// the shared PageView tick drives it from whichever page is up.
class ClockView extends PageView {

    // Weekday/month names are built here rather than taken from Gregorian's
    // localised strings: on a watch set to a non-Latin language those would
    // render as tofu in the Roboto font set the app draws with.
    private static const DAY_NAMES = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];

    public function initialize(recorder as ActivityRecorder, tracker as SplitTracker,
                               store as SplitStore) {
        PageView.initialize(recorder, tracker, store, 3);
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        beginFrame(dc, "TIME");

        var clock = System.getClockTime();

        // headline: hours and minutes, in the watch's own 12/24 hour setting
        PageChrome.centered(dc, 0.335, hoursMinutes(clock),
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT);

        // seconds tick alongside, small enough not to compete with the headline
        PageChrome.centered(dc, 0.455, clock.sec.format("%02d"),
            Graphics.FONT_MEDIUM, Theme.ACCENT_SOFT);

        PageChrome.rule(dc, 0.53, 0.62);

        PageChrome.centered(dc, 0.595, dateLabel(), Graphics.FONT_TINY, Theme.TEXT);

        PageChrome.rule(dc, 0.665, 0.72);

        // the run keeps going while this page is up, so keep it in view
        PageChrome.label(dc, 0.30, 0.715, "RUN");
        PageChrome.label(dc, 0.70, 0.715, "BATT %");
        PageChrome.value(dc, 0.30, 0.785, _recorder.getElapsedLabel(), Theme.TEXT);
        PageChrome.value(dc, 0.70, 0.785, batteryLabel(), Theme.TEXT);
        PageChrome.columnRule(dc, 0.685, 0.825);

        endFrame(dc);
    }

    // FONT_NUMBER_MEDIUM carries digits and separators only, so no AM/PM here;
    // 12-hour watches get the hour folded into 1-12 instead.
    private function hoursMinutes(clock as System.ClockTime) as String {
        var hour = clock.hour;
        if (!System.getDeviceSettings().is24Hour) {
            hour = hour % 12;
            if (hour == 0) {
                hour = 12;
            }
        }
        return Lang.format("$1$:$2$", [hour.format("%02d"), clock.min.format("%02d")]);
    }

    private function dateLabel() as String {
        var info = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        // FORMAT_SHORT keeps every field numeric: day_of_week is 1 (Sunday) to 7
        var dayIndex = info.day_of_week - 1;
        var day = (dayIndex >= 0 && dayIndex < DAY_NAMES.size()) ? DAY_NAMES[dayIndex] : "";
        return Lang.format("$1$ $2$/$3$", [day, info.month.format("%02d"), info.day.format("%02d")]);
    }

    private function batteryLabel() as String {
        return System.getSystemStats().battery.format("%d");
    }
}
