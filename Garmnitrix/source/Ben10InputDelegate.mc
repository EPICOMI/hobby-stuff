// ============================================================
//  Ben10InputDelegate.mc
//  Physical button capture for the Omnitrix interaction matrix.
//  Uses WatchUi.BehaviorDelegate (requires Watch App container).
//
//  Button mapping (Garmin Forerunner 165):
//    START (ENTER) => Trigger transformation flash / confirm selection
//    UP            => Cycle alien selection forward
//    DOWN          => Cycle alien selection backward
//    BACK (LAP)    => Exit transformation mode without selecting
//
//  Flash simulation:
//    Two-phase approach: on START press, push a FlashView that
//    renders a full-screen white fill for one frame, then pops
//    itself and applies the state transition. This gives the
//    visual transformation flash effect within Garmin's single-
//    threaded rendering model (no async/setTimeout available).
// ============================================================

import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Graphics;

class Ben10InputDelegate extends WatchUi.BehaviorDelegate {

    private var _view as Ben10OmnitrixView;

    function initialize(view as Ben10OmnitrixView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    // Raw key event handler
    function onKey(keyEvent as WatchUi.KeyEvent) as Lang.Boolean {
        var key = keyEvent.getKey();

        // START / ENTER
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            if (!_view.isTransformMode) {
                _triggerFlash(1);  // Phase 1: enter selection mode
            } else {
                _triggerFlash(2);  // Phase 2: confirm alien, return to idle
            }
            return true;
        }

        // UP: cycle forward through aliens
        if (key == WatchUi.KEY_UP) {
            if (_view.isTransformMode) {
                _view.cycleAlien(1);
            }
            return true;
        }

        // DOWN: cycle backward through aliens
        if (key == WatchUi.KEY_DOWN) {
            if (_view.isTransformMode) {
                _view.cycleAlien(-1);
            }
            return true;
        }

        // BACK / LAP: cancel selection mode
        if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_LAP) {
            if (_view.isTransformMode) {
                _view.exitTransformMode();
            }
            return true;
        }

        return false;
    }

    // BehaviorDelegate overrides
    function onBack() as Lang.Boolean {
        if (_view.isTransformMode) {
            _view.exitTransformMode();
            return true;
        }
        return false;
    }

    function onSelect() as Lang.Boolean {
        if (!_view.isTransformMode) {
            _triggerFlash(1);
        } else {
            _triggerFlash(2);
        }
        return true;
    }

    // Push a white-flash overlay view, applying state on its second frame
    private function _triggerFlash(phase as Lang.Number) as Void {
        var flashView = new FlashView(_view, phase);
        WatchUi.pushView(flashView, new FlashDelegate(), WatchUi.SLIDE_IMMEDIATE);
    }
}

// ---- FlashView ---------------------------------------------
// One-frame white fill, then pops itself after state transition
class FlashView extends WatchUi.View {
    private var _parent  as Ben10OmnitrixView;
    private var _phase   as Lang.Number;
    private var _painted as Lang.Boolean = false;

    function initialize(parent as Ben10OmnitrixView, phase as Lang.Number) {
        View.initialize();
        _parent = parent;
        _phase  = phase;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_WHITE);
        dc.clear();

        if (!_painted) {
            _painted = true;
            // Request one more frame so user sees the white flash
            WatchUi.requestUpdate();
        } else {
            // Second frame: apply state and pop
            if (_phase == 1) {
                _parent.enterTransformMode();
            } else {
                _parent.exitTransformMode();
            }
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
    }
}

// ---- FlashDelegate -----------------------------------------
// Blocks all input while the flash is displayed
class FlashDelegate extends WatchUi.BehaviorDelegate {
    function initialize() { BehaviorDelegate.initialize(); }
    function onKey(keyEvent as WatchUi.KeyEvent) as Lang.Boolean { return true; }
    function onBack() as Lang.Boolean { return true; }
    function onSelect() as Lang.Boolean { return true; }
}
