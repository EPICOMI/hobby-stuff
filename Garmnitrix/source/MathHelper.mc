// ============================================================
//  MathHelper.mc
//  Wraps Toybox.Math trig functions so they are accessible
//  without the Math. namespace qualifier in older SDK targets.
//  Also houses utility geometry helpers.
// ============================================================

import Toybox.Math;
import Toybox.Lang;

module MathHelper {

    // Degrees → radians
    function toRad(degrees as Lang.Float) as Lang.Float {
        return degrees * (Math.PI / 180.0f);
    }

    // Clamp a value between lo and hi
    function clamp(value as Lang.Number, lo as Lang.Number, hi as Lang.Number) as Lang.Number {
        if (value < lo) { return lo; }
        if (value > hi) { return hi; }
        return value;
    }

    // Clamp a float value between lo and hi
    function clampF(value as Lang.Float, lo as Lang.Float, hi as Lang.Float) as Lang.Float {
        if (value < lo) { return lo; }
        if (value > hi) { return hi; }
        return value;
    }
}
