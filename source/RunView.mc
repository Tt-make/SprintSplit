import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// Page 1: the run itself. Recording starts at launch, so this page is live
// from the moment the app opens.
class RunView extends PageView {

    public function initialize(recorder as ActivityRecorder, tracker as SplitTracker,
                               store as SplitStore) {
        PageView.initialize(recorder, tracker, store, 0);
    }

    public function onUpdate(dc as Graphics.Dc) as Void {
        beginFrame(dc, "RUN");

        // headline: elapsed activity time
        PageChrome.centered(dc, 0.285, _recorder.getElapsedLabel(),
            Graphics.FONT_NUMBER_MEDIUM, Theme.TEXT);

        PageChrome.rule(dc, 0.365, 0.66);

        // row 1: distance | speed
        PageChrome.label(dc, 0.30, 0.415, "DIST km");
        PageChrome.label(dc, 0.70, 0.415, "SPEED km/h");
        PageChrome.value(dc, 0.30, 0.485, _recorder.getDistanceLabel(), Theme.TEXT);
        PageChrome.value(dc, 0.70, 0.485, _recorder.getSpeedLabel(), Theme.ACCENT_SOFT);
        PageChrome.columnRule(dc, 0.385, 0.525);

        PageChrome.rule(dc, 0.535, 0.72);

        // row 2: heart rate | cadence
        PageChrome.label(dc, 0.30, 0.585, "HR bpm");
        PageChrome.label(dc, 0.70, 0.585, "CAD spm");
        PageChrome.value(dc, 0.30, 0.655, _recorder.getHeartRateValue(), Theme.TEXT);
        PageChrome.value(dc, 0.70, 0.655, _recorder.getCadenceValue(), Theme.TEXT);
        PageChrome.columnRule(dc, 0.555, 0.695);

        PageChrome.rule(dc, 0.705, 0.66);

        // row 3: the run's fastest speed, alongside calories
        PageChrome.label(dc, 0.30, 0.755, "MAX km/h");
        PageChrome.label(dc, 0.70, 0.755, "KCAL");
        PageChrome.value(dc, 0.30, 0.825, _recorder.getMaxSpeedLabel(), Theme.ACCENT_SOFT);
        PageChrome.value(dc, 0.70, 0.825, _recorder.getCaloriesValue(), Theme.TEXT);
        PageChrome.columnRule(dc, 0.725, 0.865);

        endFrame(dc);
    }
}
