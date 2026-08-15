import Toybox.Lang;
import Toybox.Attention;

// One completed (or abandoned) rep: the speed sampled once a second for the
// whole rep, the times each split was reached with the speed there, and the
// fastest speed seen while the rep clock ran.
class RepResult {
    public var samples as Array<Float>;
    public var splitTimes as Array<Float>;
    public var splitSpeeds as Array<Float>;
    public var peakSpeedMps as Float;

    public function initialize(secondSamples as Array<Float>, times as Array<Float>,
                               speeds as Array<Float>, peak as Float) {
        samples = secondSamples;
        splitTimes = times;
        splitSpeeds = speeds;
        peakSpeedMps = peak;
    }

    public function totalSeconds() as Float {
        if (splitTimes.size() == 0) {
            return 0.0;
        }
        return splitTimes[splitTimes.size() - 1];
    }
}

// Sub feature: on-demand split/interval alerts (e.g. for 100m/200m/400m reps),
// layered on top of ActivityRecorder's elapsed clock so both share one clock
// source. With delayed start enabled, Select begins a countdown; an alert marks
// "go" and only then does the interval clock run toward the configured split
// seconds.
//
// A rep is a full set of splits: once the last configured split is reached the
// clock stops on its own, the result is filed away, and the app jumps to the
// speed curve. Select then starts the next rep — a session is normally many
// reps, and each one's result is kept for comparison and written to the FIT
// activity as laps.
class SplitTracker {

    private const STATE_OFF = 0;
    private const STATE_COUNTDOWN = 1;
    private const STATE_RUNNING = 2;
    private const STATE_DONE = 3;

    // enough reps to look back over a session without growing without bound
    private const MAX_HISTORY = 12;

    // the speed curve is built from one sample per second; 600 covers the
    // longest split the pickers allow (600s)
    private const MAX_SAMPLES = 600;

    private var _store as SplitStore;
    private var _recorder as ActivityRecorder;
    private var _state as Number = STATE_OFF;
    private var _targets as Array<Number> = [] as Array<Number>;
    private var _nextSplitIndex as Number = 0;
    private var _achievedSplits as Array<Float> = [] as Array<Float>;
    private var _splitSpeeds as Array<Float> = [] as Array<Float>;
    private var _phaseStartMs as Number = 0;
    private var _phaseElapsedMs as Number = 0;
    private var _peakSpeedMps as Float = 0.0;
    private var _samples as Array<Float> = [] as Array<Float>;
    private var _nextSampleSecond as Number = 1;
    private var _history as Array<RepResult> = [] as Array<RepResult>;
    private var _justFinished as Boolean = false;

    public function initialize(store as SplitStore, recorder as ActivityRecorder) {
        _store = store;
        _recorder = recorder;
        _targets = store.getSplits();
    }

    public function isOff() as Boolean {
        return _state == STATE_OFF;
    }

    public function isCountingDown() as Boolean {
        return _state == STATE_COUNTDOWN;
    }

    public function isRunning() as Boolean {
        return _state == STATE_RUNNING;
    }

    public function isDone() as Boolean {
        return _state == STATE_DONE;
    }

    // mainElapsedMs is ActivityRecorder.getElapsedMs(): the single shared clock
    public function toggle(mainElapsedMs as Number) as Void {
        if (_state == STATE_COUNTDOWN || _state == STATE_RUNNING) {
            // stopped by hand: keep whatever was measured so far
            fileCurrentRep();
            _state = STATE_OFF;
            _recorder.markLap();
            return;
        }

        startRep(mainElapsedMs);
    }

    // Begins a fresh rep from OFF or from a finished one.
    private function startRep(mainElapsedMs as Number) as Void {
        // pick up any edits made since the last rep
        _targets = _store.getSplits();
        _nextSplitIndex = 0;
        _achievedSplits = [] as Array<Float>;
        _splitSpeeds = [] as Array<Float>;
        _phaseStartMs = mainElapsedMs;
        _phaseElapsedMs = 0;
        _peakSpeedMps = 0.0;
        _samples = [] as Array<Float>;
        _nextSampleSecond = 1;
        _justFinished = false;

        if (_store.isDelayEnabled()) {
            _state = STATE_COUNTDOWN;
        } else {
            startRunning();
        }
    }

    private function startRunning() as Void {
        signalGo();
        _state = STATE_RUNNING;
        _recorder.markLap();
    }

    public function reset() as Void {
        _state = STATE_OFF;
        _targets = _store.getSplits();
        _nextSplitIndex = 0;
        _achievedSplits = [] as Array<Float>;
        _splitSpeeds = [] as Array<Float>;
        _phaseElapsedMs = 0;
        _peakSpeedMps = 0.0;
        _samples = [] as Array<Float>;
        _nextSampleSecond = 1;
        _justFinished = false;
    }

    // Alerts honour the sound / vibrate / both setting, and skip anything the
    // watch cannot do.
    private function alert(vibeProfile as Array<Attention.VibeProfile>,
                           tone as Attention.Tone) as Void {
        if (_store.isVibrateEnabled() && (Attention has :vibrate)) {
            Attention.vibrate(vibeProfile);
        }
        if (_store.isSoundEnabled() && (Attention has :playTone)) {
            Attention.playTone(tone);
        }
    }

    private function signalGo() as Void {
        alert([new Attention.VibeProfile(100, 500)] as Array<Attention.VibeProfile>,
            Attention.TONE_START);
    }

    private function signalSplit() as Void {
        alert([new Attention.VibeProfile(75, 300)] as Array<Attention.VibeProfile>,
            Attention.TONE_LOUD_BEEP);
    }

    // Distinct from a split alert, so the end of the rep is unmistakable.
    private function signalFinish() as Void {
        alert([new Attention.VibeProfile(100, 300),
               new Attention.VibeProfile(0, 150),
               new Attention.VibeProfile(100, 300)] as Array<Attention.VibeProfile>,
            Attention.TONE_STOP);
    }

    public function update(mainElapsedMs as Number, currentSpeedMps as Float) as Void {
        if (_state == STATE_OFF || _state == STATE_DONE) {
            // a finished rep keeps its final time on screen
            return;
        }

        _phaseElapsedMs = mainElapsedMs - _phaseStartMs;

        if (_state == STATE_COUNTDOWN) {
            if (_phaseElapsedMs >= _store.getDelaySeconds() * 1000) {
                startRunning();
                _phaseStartMs = mainElapsedMs;
                _phaseElapsedMs = 0;
            }
            return;
        }

        // the peak only counts once the rep is actually under way, so the
        // countdown's warm-up speed never shows up as the measured maximum
        if (currentSpeedMps > _peakSpeedMps) {
            _peakSpeedMps = currentSpeedMps;
        }

        sampleSpeed(currentSpeedMps);
        checkSplits(currentSpeedMps);
    }

    // One reading per whole second of the rep, which is what the speed curve is
    // drawn from. The 200ms tick means a second is never missed; the loop only
    // matters if a tick is late.
    private function sampleSpeed(currentSpeedMps as Float) as Void {
        while (_phaseElapsedMs >= _nextSampleSecond * 1000 && _samples.size() < MAX_SAMPLES) {
            _samples.add(currentSpeedMps);
            _nextSampleSecond += 1;
        }
    }

    private function checkSplits(currentSpeedMps as Float) as Void {
        var elapsedSeconds = _phaseElapsedMs / 1000.0;
        var reached = false;
        while (_nextSplitIndex < _targets.size() &&
               elapsedSeconds >= _targets[_nextSplitIndex]) {
            _achievedSplits.add(elapsedSeconds);
            _splitSpeeds.add(currentSpeedMps);
            _nextSplitIndex += 1;
            reached = true;
            _recorder.recordSplit(currentSpeedMps);
        }

        if (!reached) {
            return;
        }

        if (_nextSplitIndex >= _targets.size() && _targets.size() > 0) {
            finishRep();
        } else {
            // one alert per tick even if several targets elapsed together
            signalSplit();
        }
    }

    // Every configured split is done: stop the clock, keep the result, and let
    // the UI know it should show the speed curve.
    private function finishRep() as Void {
        _state = STATE_DONE;
        signalFinish();
        var rep = fileCurrentRep();
        if (rep != null) {
            _recorder.recordRep(rep.totalSeconds());
        }
        _justFinished = true;
    }

    // Moves the rep just measured into the history. Returns null when there is
    // nothing worth keeping (stopped before the first split).
    private function fileCurrentRep() as RepResult? {
        if (_achievedSplits.size() == 0 && _samples.size() == 0) {
            return null;
        }
        var rep = new RepResult(_samples, _achievedSplits, _splitSpeeds, _peakSpeedMps);
        _history.add(rep);
        if (_history.size() > MAX_HISTORY) {
            _history = _history.slice(_history.size() - MAX_HISTORY, null);
        }
        return rep;
    }

    // Read once by PageView, which then switches to the speed curve page.
    public function takeJustFinished() as Boolean {
        if (!_justFinished) {
            return false;
        }
        _justFinished = false;
        return true;
    }

    public function getTargets() as Array<Number> {
        return _targets;
    }

    // "P1" — which of the three saved sets the reps are running against.
    public function getPresetLabel() as String {
        return Lang.format("P$1$", [_store.getActivePreset() + 1]);
    }

    // The curve on screen: one speed per second of the rep being measured, or
    // of the last one completed.
    public function getCurveSamples() as Array<Float> {
        if (_samples.size() > 0) {
            return _samples;
        }
        var last = getLastRep();
        return last != null ? last.samples : ([] as Array<Float>);
    }

    public function getLastRep() as RepResult? {
        if (_history.size() == 0) {
            return null;
        }
        return _history[_history.size() - 1];
    }

    // The rep before the one on screen, drawn faintly for comparison.
    public function getPreviousRep() as RepResult? {
        var index = (_samples.size() > 0) ? _history.size() - 1 : _history.size() - 2;
        if (index < 0) {
            return null;
        }
        return _history[index];
    }

    public function getCompletedRepCount() as Number {
        return _history.size();
    }

    // "REP 3" while measuring, and the number of the last one once finished.
    public function getRepLabel() as String {
        if (_samples.size() > 0 && _state != STATE_DONE) {
            return Lang.format("REP $1$", [_history.size() + 1]);
        }
        if (_history.size() == 0) {
            return "";
        }
        return Lang.format("REP $1$", [_history.size()]);
    }

    public function getAchievedCount() as Number {
        return _achievedSplits.size();
    }

    public function getTargetCount() as Number {
        return _targets.size();
    }


    // Fastest speed seen while the rep clock was running. Falls back to the
    // last rep and then to the whole session's maximum, so the speed curve page
    // always has a number to show.
    public function getPeakSpeedMps() as Float {
        if (_peakSpeedMps > 0.0) {
            return _peakSpeedMps;
        }
        var last = getLastRep();
        if (last != null && last.peakSpeedMps > 0.0) {
            return last.peakSpeedMps;
        }
        return _recorder.getMaxSpeedMps();
    }

    public function getStatusLabel() as String {
        if (_state == STATE_COUNTDOWN) {
            var remainingMs = (_store.getDelaySeconds() * 1000) - _phaseElapsedMs;
            if (remainingMs < 0) {
                remainingMs = 0;
            }
            return Lang.format("READY $1$", [(remainingMs + 999) / 1000]);
        }
        if (_state == STATE_RUNNING) {
            return "RUNNING";
        }
        if (_state == STATE_DONE) {
            return "DONE";
        }
        return "READY";
    }

    // Rendered with FONT_NUMBER_MEDIUM, which carries digits and separators
    // only — never return letters or dashes from here.
    public function getRepElapsedLabel() as String {
        if (_state == STATE_OFF) {
            return "0.0";
        }
        var totalSeconds = _phaseElapsedMs / 1000;
        var tenths = (_phaseElapsedMs % 1000) / 100;
        return Lang.format("$1$.$2$", [totalSeconds.format("%d"), tenths.format("%d")]);
    }

    public function getNextSplitLabel() as String {
        if (_targets.size() == 0) {
            return "NO SPLITS SET";
        }
        if (_state == STATE_DONE) {
            return "SELECT = NEXT REP";
        }
        if (_state == STATE_OFF) {
            return _history.size() > 0
                ? Lang.format("$1$ REPS DONE", [_history.size()])
                : Lang.format("$1$ SPLITS LOADED", [_targets.size()]);
        }
        if (_state == STATE_COUNTDOWN) {
            return "GET SET";
        }
        var target = _targets[_nextSplitIndex];
        var remaining = target - (_phaseElapsedMs / 1000.0);
        if (remaining < 0.0) {
            remaining = 0.0;
        }
        return Lang.format("NEXT $1$s  -$2$s", [target, remaining.format("%.1f")]);
    }

    public function getLastSplitLabel() as String {
        if (_achievedSplits.size() == 0) {
            return "";
        }
        var last = _achievedSplits[_achievedSplits.size() - 1];
        var lastSpeed = _splitSpeeds[_splitSpeeds.size() - 1] * 3.6;
        return Lang.format("LAST $1$s  $2$km/h", [last.format("%.2f"), lastSpeed.format("%.1f")]);
    }
}
