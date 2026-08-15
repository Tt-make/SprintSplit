import Toybox.Lang;
import Toybox.System;
import Toybox.Position;
import Toybox.Sensor;
import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;

// Owns the always-on FIT recording session. Recording starts the instant the
// app opens (see SprintSplitApp.getInitialView) so every metric the watch can
// capture for a run — GPS pace/distance, heart rate, cadence, calories,
// elevation, etc. — ends up in Garmin Connect like a normal run activity.
// Each split also closes a FIT lap, so the reps show up as laps on the
// activity page, and the peak speed is written as an activity-level FIT field.
class ActivityRecorder {
    private var _session as ActivityRecording.Session?;
    private var _positionEnabled as Boolean = false;
    private var _elapsedMs as Number = 0;
    private var _currentSpeedMps as Float = 0.0;
    private var _maxSpeedMps as Float = 0.0;
    private var _distanceMeters as Float = 0.0;
    private var _heartRate as Number?;
    private var _cadence as Number?;
    private var _calories as Number?;
    private var _lapCount as Number = 0;
    private var _maxSpeedField as FitContributor.Field?;
    private var _splitCountField as FitContributor.Field?;
    private var _repCountField as FitContributor.Field?;
    private var _bestRepField as FitContributor.Field?;
    private var _lapSpeedField as FitContributor.Field?;
    private var _splitsRecorded as Number = 0;
    private var _repsCompleted as Number = 0;
    private var _bestRepSeconds as Float = 0.0;

    public function start() as Void {
        if (!_positionEnabled) {
            Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
            _positionEnabled = true;
        }

        if (Toybox has :Sensor) {
            // Ensures heart rate / footpod / temperature are pulled into the
            // FIT record alongside GPS, mirroring what the built-in Run app records.
            Sensor.setEnabledSensors([
                Sensor.SENSOR_HEARTRATE,
                Sensor.SENSOR_FOOTPOD,
                Sensor.SENSOR_TEMPERATURE
            ]);
        }

        if (Toybox has :ActivityRecording) {
            _session = ActivityRecording.createSession({
                :name => "Run",
                :sport => Activity.SPORT_RUNNING,
                :subSport => Activity.SUB_SPORT_TRACK
            });
            createFitFields();
            _session.start();
        }
    }

    // Extra activity-level numbers Garmin Connect shows next to the standard
    // run metrics. Older devices may not carry FitContributor, so every step
    // here is optional.
    private function createFitFields() as Void {
        var session = _session;
        if (session == null || !(Toybox has :FitContributor)) {
            return;
        }
        _maxSpeedField = session.createField("max_speed", 0, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "km/h"});
        _splitCountField = session.createField("splits", 1, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "n"});
        _repCountField = session.createField("reps", 2, FitContributor.DATA_TYPE_UINT16,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "n"});
        _bestRepField = session.createField("best_rep", 3, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_SESSION, :units => "s"});
        // per-lap: the speed measured at the split that closed the lap
        _lapSpeedField = session.createField("split_speed", 4, FitContributor.DATA_TYPE_FLOAT,
            {:mesgType => FitContributor.MESG_TYPE_LAP, :units => "km/h"});
        writeFitFields();
    }

    private function writeFitFields() as Void {
        var maxField = _maxSpeedField;
        if (maxField != null) {
            maxField.setData(_maxSpeedMps * 3.6);
        }
        var splitField = _splitCountField;
        if (splitField != null) {
            splitField.setData(_splitsRecorded);
        }
        var repField = _repCountField;
        if (repField != null) {
            repField.setData(_repsCompleted);
        }
        var bestField = _bestRepField;
        if (bestField != null) {
            bestField.setData(_bestRepSeconds);
        }
    }

    public function isRecording() as Boolean {
        return _session != null && _session.isRecording();
    }

    // Closes the current lap so a rep or a split shows as its own lap in
    // Garmin Connect. Called by SplitTracker at "go" and at every split second.
    public function markLap() as Void {
        var session = _session;
        if (session == null || !session.isRecording()) {
            return;
        }
        if (session has :addLap) {
            session.addLap();
            _lapCount += 1;
        }
    }

    // A split was reached: tag the lap with the speed measured there, close it,
    // and keep the running count for the activity summary.
    public function recordSplit(speedMps as Float) as Void {
        var lapField = _lapSpeedField;
        if (lapField != null) {
            lapField.setData(speedMps * 3.6);
        }
        _splitsRecorded += 1;
        writeFitFields();
        markLap();
    }

    // A full set of splits finished. Kept as an activity-level summary so the
    // session's rep count and best rep are visible in Garmin Connect.
    public function recordRep(totalSeconds as Float) as Void {
        _repsCompleted += 1;
        if (totalSeconds > 0.0 && (_bestRepSeconds <= 0.0 || totalSeconds < _bestRepSeconds)) {
            _bestRepSeconds = totalSeconds;
        }
        writeFitFields();
    }

    public function getRepCount() as Number {
        return _repsCompleted;
    }

    public function getLapCount() as Number {
        return _lapCount;
    }

    public function stopAndSave() as Void {
        finishPositionTracking();
        var session = _session;
        if (session != null) {
            writeFitFields();
            if (session.isRecording()) {
                session.stop();
            }
            // save() hands the FIT file to the system, which syncs it to the
            // Garmin Connect app as a normal run activity on the next sync.
            session.save();
            _session = null;
        }
    }

    public function stopAndDiscard() as Void {
        finishPositionTracking();
        var session = _session;
        if (session != null) {
            if (session.isRecording()) {
                session.stop();
            }
            session.discard();
            _session = null;
        }
    }

    private function finishPositionTracking() as Void {
        if (_positionEnabled) {
            Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
            _positionEnabled = false;
        }
    }

    public function onPosition(info as Position.Info) as Void {
        var speed = info.speed;
        if (speed != null) {
            _currentSpeedMps = speed;
            trackMaxSpeed(speed);
        }
    }

    private function trackMaxSpeed(speed as Float) as Void {
        if (speed > _maxSpeedMps) {
            _maxSpeedMps = speed;
            writeFitFields();
        }
    }

    public function update() as Void {
        var info = Activity.getActivityInfo();

        var elapsed = info.elapsedTime;
        if (elapsed != null) {
            _elapsedMs = elapsed;
        } else {
            _elapsedMs += 200;
        }

        var speed = info.currentSpeed;
        if (speed != null) {
            _currentSpeedMps = speed;
            trackMaxSpeed(speed);
        }

        var distance = info.elapsedDistance;
        if (distance != null) {
            _distanceMeters = distance;
        }

        _heartRate = info.currentHeartRate;
        _cadence = info.currentCadence;
        _calories = info.calories;
    }

    public function getElapsedMs() as Number {
        return _elapsedMs;
    }

    public function getSpeedMps() as Float {
        return _currentSpeedMps;
    }

    // Fastest speed seen since the app opened, across every rep.
    public function getMaxSpeedMps() as Float {
        return _maxSpeedMps;
    }

    public function getElapsedLabel() as String {
        var totalSeconds = _elapsedMs / 1000;
        var minutes = totalSeconds / 60;
        var seconds = totalSeconds % 60;
        return Lang.format("$1$:$2$", [minutes.format("%02d"), seconds.format("%02d")]);
    }

    public function getDistanceLabel() as String {
        var km = _distanceMeters / 1000.0;
        return km.format("%.2f");
    }

    public function getSpeedLabel() as String {
        var kmh = _currentSpeedMps * 3.6;
        return kmh.format("%.1f");
    }

    public function getMaxSpeedLabel() as String {
        var kmh = _maxSpeedMps * 3.6;
        return kmh.format("%.1f");
    }

    // Bare values for the two-column rows, which carry their own headings.
    // All labels stay ASCII: the simulator (and any watch set to a Latin
    // language) loads only the Roboto font set, so other glyphs render as tofu.
    public function getHeartRateValue() as String {
        var hr = _heartRate;
        return hr != null ? hr.toString() : "--";
    }

    public function getCadenceValue() as String {
        var cad = _cadence;
        return cad != null ? cad.toString() : "--";
    }

    public function getCaloriesValue() as String {
        var cal = _calories;
        return cal != null ? cal.toString() : "--";
    }
}
