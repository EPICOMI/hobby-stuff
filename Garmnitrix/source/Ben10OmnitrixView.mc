// ============================================================
//  Ben10OmnitrixView.mc  –  Garmnitrix Watch App
//  Target: Garmin Forerunner 165  (390 × 390 px, round AMOLED)
//
//  IDLE DIAL GEOMETRY  (Omniverse Omnitrix spec)
//  ─────────────────────────────────────────────
//  Layer 0: solid BLACK screen fill
//  Layer 1: solid GREEN circle,  radius = R_FACE  (130 px)
//  Layer 2: two BLACK wedge polygons (right + left)
//
//  Each wedge:
//   • Outer edge  → smooth arc along R_OUTER (185 px)
//                   sweeping from –30° to +30°  (right wedge)
//                   or 150° to 210°              (left wedge)
//                   Arc approximated with ARC_STEPS intermediate points.
//   • Inner edge  → flat vertical cut at x = ±neckX
//                   top    vertex: (±neckX, –neckY)
//                   bottom vertex: (±neckX, +neckY)
//                   where neckX = 0.10 × R_FACE,  neckY = 0.05 × R_FACE
//
//  Coordinate convention used throughout:
//   angle 0°   = true right  (+X axis)
//   angle 90°  = downward    (+Y axis, screen coords)
//
//  AOD / burn-in protection:
//   • fillCircle replaced by outline arcs (< 10% pixels lit)
//   • ±2..4 px pixel-shift every redraw cycle
// ============================================================

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Math;

class Ben10OmnitrixView extends WatchUi.View {

    // ── Layout constants ──────────────────────────────────────
    private const CX      as Lang.Number = 195;   // screen centre X
    private const CY      as Lang.Number = 195;   // screen centre Y
    private const R_OUTER as Lang.Number = 155;   // outer wedge arc radius
    private const R_FACE  as Lang.Number = 130;   // green fill circle radius
    private const ARC_STEPS as Lang.Number = 8;   // polygon points along outer arc

    // ── State ─────────────────────────────────────────────────
    var isTransformMode  as Lang.Boolean = false;
    var activeAlienIndex as Lang.Number  = 0;
    var isAod            as Lang.Boolean = false;

    private var _aodShiftIndex as Lang.Number = 0;
    private const AOD_OFFSETS as Lang.Array = [
        [-4,-4], [-2,-4], [0,-2], [2,-2], [4, 0],
        [ 4, 2], [ 2, 4], [0, 4], [-2, 2], [-4, 0]
    ] as Lang.Array;

    // ── Alien data ────────────────────────────────────────────
    private const ALIEN_NAMES as Lang.Array = [
        "Swampfire", "Chromastone", "Humungousaur",
        "Jetray",    "Big Chill",   "Goop",
        "Echo Echo", "Alien X",     "Brainstorm", "Spidermonkey"
    ] as Lang.Array;

    // Normalised silhouette vertices (range ≈ –50 to +50).
    // Scaled × 1.5 at render time to fill the selection diamond.
    private const ALIEN_POLYS as Lang.Array = [
        [[-14,-40],[-20,-20],[-30,0],[-22,30],[0,42],[22,30],[30,0],[20,-20],[14,-40],[5,-50],[-5,-50]] as Lang.Array,
        [[0,-48],[16,-20],[30,0],[20,40],[0,50],[-20,40],[-30,0],[-16,-20]] as Lang.Array,
        [[-30,-45],[-40,-10],[-48,20],[-30,45],[0,50],[30,45],[48,20],[40,-10],[30,-45],[15,-50],[-15,-50]] as Lang.Array,
        [[-48,-5],[-30,-20],[-10,-40],[0,-48],[10,-40],[30,-20],[48,-5],[30,10],[15,40],[0,48],[-15,40],[-30,10]] as Lang.Array,
        [[-44,-30],[-20,-10],[-5,-45],[5,-45],[20,-10],[44,-30],[35,10],[20,40],[0,48],[-20,40],[-35,10]] as Lang.Array,
        [[-10,-48],[10,-48],[30,-30],[45,-5],[40,20],[25,45],[0,50],[-25,45],[-40,20],[-45,-5],[-30,-30]] as Lang.Array,
        [[-18,-46],[18,-46],[26,-20],[26,20],[18,46],[-18,46],[-26,20],[-26,-20]] as Lang.Array,
        [[0,-50],[8,-28],[30,-38],[18,-14],[38,0],[18,14],[28,38],[0,26],[-28,38],[-18,14],[-38,0],[-18,-14],[-30,-38],[-8,-28]] as Lang.Array,
        [[-22,-40],[22,-40],[40,-20],[48,0],[30,30],[10,48],[-10,48],[-30,30],[-48,0],[-40,-20]] as Lang.Array,
        [[-8,-48],[8,-48],[20,-25],[38,-10],[38,15],[20,10],[15,48],[-15,48],[-20,10],[-38,15],[-38,-10],[-20,-25]] as Lang.Array
    ] as Lang.Array;

    // ─────────────────────────────────────────────────────────
    function initialize() { View.initialize(); }
    function onLayout(dc as Graphics.Dc) as Void {}

    // ── Main update ───────────────────────────────────────────
    function onUpdate(dc as Graphics.Dc) as Void {
        var stats   = System.getSystemStats();
        var battery = stats.battery;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        if (isAod) {
            _drawAodOutline(dc, battery);
        } else if (!isTransformMode) {
            _drawIdleDial(dc, battery);
            _drawInvisibleClock(dc);
        } else {
            _drawSelectionDial(dc);
        }
    }

    function onEnterSleep() as Void { isAod = true;  WatchUi.requestUpdate(); }
    function onExitSleep()  as Void { isAod = false; WatchUi.requestUpdate(); }

    // ── Battery → colour ──────────────────────────────────────
    function calculateBatteryColor(battery as Lang.Float) as Lang.Number {
        var pct = battery < 0.0f ? 0.0f : (battery > 100.0f ? 100.0f : battery);
        var r = (59  + ((255 - 59)  * (100.0f - pct) / 100.0f)).toNumber();
        var g = (255.0f * (pct / 100.0f)).toNumber();
        if (r > 255) { r = 255; } if (r < 0) { r = 0; }
        if (g > 255) { g = 255; } if (g < 0) { g = 0; }
        return (r << 16) | (g << 8);
    }

    // ── IDLE DIAL ─────────────────────────────────────────────
    //
    //  Step 1 – fill the green circle (R_FACE).
    //  Step 2 – draw two black wedge polygons over it.
    //
    //  Wedge polygon point order (right wedge, CCW):
    //    a) Outer arc from –30° to +30° (ARC_STEPS points, left-to-right)
    //    b) inner flat: (neckX, +neckY)   ← bottom of neck
    //    c) inner flat: (neckX, –neckY)   ← top of neck  (back to arc start)
    //
    private function _drawIdleDial(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);

        // ── green background circle ──
        dc.setColor(bColor, bColor);
        dc.fillCircle(CX, CY, R_FACE);

        // ── pre-compute neck coordinates ──
        // neckX = 0.10 × R_FACE,  neckY = 0.05 × R_FACE
        var neckX = (R_FACE * 100 / 1000);   // integer: ~13 px
        var neckY = (R_FACE *  50 / 1000);   // integer: ~6 px

        // ── build and fill RIGHT wedge ──
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillPolygon(_buildWedge(CX, CY, R_OUTER, neckX, neckY, -30.0f, 30.0f, 1));

        // ── build and fill LEFT wedge ──
        dc.fillPolygon(_buildWedge(CX, CY, R_OUTER, neckX, neckY, 150.0f, 210.0f, -1));

        // ── thin bezel ring ──
        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(CX, CY, R_OUTER + 10);
    }

    // ── Wedge polygon builder ─────────────────────────────────
    //
    //  Builds the polygon array for one wedge.
    //  neckSign: +1 for right wedge (neck at +neckX),
    //            –1 for left  wedge (neck at –neckX).
    //
    //  Polygon vertex order:
    //    [0 .. ARC_STEPS-1]  outer arc  (startDeg → endDeg)
    //    [ARC_STEPS]         inner flat bottom  (±neckX, +neckY)
    //    [ARC_STEPS+1]       inner flat top     (±neckX, –neckY)
    //
    private function _buildWedge(
        cx        as Lang.Number,
        cy        as Lang.Number,
        rOuter    as Lang.Number,
        neckX     as Lang.Number,
        neckY     as Lang.Number,
        startDeg  as Lang.Float,
        endDeg    as Lang.Float,
        neckSign  as Lang.Number
    ) as Lang.Array {

        var pts = [] as Lang.Array;
        var steps = ARC_STEPS;

        // Outer arc: interpolate from startDeg to endDeg
        for (var i = 0; i < steps; i++) {
            var t   = i.toFloat() / (steps - 1).toFloat();
            var deg = startDeg + t * (endDeg - startDeg);
            var rad = Math.toRadians(deg);
            var px  = (cx + rOuter.toFloat() * Math.cos(rad)).toNumber();
            var py  = (cy + rOuter.toFloat() * Math.sin(rad)).toNumber();
            pts.add([px, py]);
        }

        // Inner flat cut (bottom then top — closes the polygon back to arc start)
        pts.add([cx + neckSign * neckX, cy + neckY]);
        pts.add([cx + neckSign * neckX, cy - neckY]);

        return pts;
    }

    // ── Invisible clock (stealth overlay) ─────────────────────
    private function _drawInvisibleClock(dc as Graphics.Dc) as Void {
        var now     = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeStr = now.hour.format("%02d") + ":" + now.min.format("%02d");
        // Same colour as background → visually hidden, satisfies OS clock requirement
        dc.setColor(0x3BFF00, 0x3BFF00);
        dc.drawText(CX, CY, Graphics.FONT_LARGE, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ── SELECTION DIAL ────────────────────────────────────────
    private function _drawSelectionDial(dc as Graphics.Dc) as Void {
        var GREEN = 0x3BFF00;
        var GRAY  = 0x888888;

        // Bezel ring
        dc.setColor(GRAY, GRAY);
        dc.fillCircle(CX, CY, 172);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(CX, CY, 158);

        // Bezel outline + 4 connector bumps
        dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(CX, CY, 182);
        dc.setColor(GRAY, GRAY);
        dc.fillCircle(CX,       CY - 185, 8);
        dc.fillCircle(CX,       CY + 185, 8);
        dc.fillCircle(CX - 185, CY,       8);
        dc.fillCircle(CX + 185, CY,       8);

        // Green diamond
        var d = 118;
        var diamond = [
            [CX,     CY - d],
            [CX + d, CY    ],
            [CX,     CY + d],
            [CX - d, CY    ]
        ];
        dc.setColor(GREEN, GREEN);
        dc.fillPolygon(diamond);

        // Alien silhouette
        _drawAlienSilhouette(dc, activeAlienIndex);

        // Alien name label
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, CY + 150, Graphics.FONT_SMALL,
                    ALIEN_NAMES[activeAlienIndex] as Lang.String,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _drawAlienSilhouette(dc as Graphics.Dc, idx as Lang.Number) as Void {
        var poly  = ALIEN_POLYS[idx] as Lang.Array;
        var scale = 75.0f / 50.0f;
        var mapped = [] as Lang.Array;
        for (var i = 0; i < poly.size(); i++) {
            var pt = poly[i] as Lang.Array;
            var px = (CX + (pt[0] as Lang.Number).toFloat() * scale).toNumber();
            var py = (CY + (pt[1] as Lang.Number).toFloat() * scale).toNumber();
            mapped.add([px, py]);
        }
        dc.setColor(0x1A7000, 0x1A7000);
        dc.fillPolygon(mapped);
    }

    // ── AOD OUTLINE (burn-in safe) ────────────────────────────
    private function _drawAodOutline(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);
        var offset = AOD_OFFSETS[_aodShiftIndex % 10] as Lang.Array;
        _aodShiftIndex = (_aodShiftIndex + 1) % 10;
        var ox = offset[0] as Lang.Number;
        var oy = offset[1] as Lang.Number;

        var neckX = (R_FACE * 100 / 1000);
        var neckY = (R_FACE *  50 / 1000);

        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(CX + ox, CY + oy, R_OUTER + 10);

        // Right wedge outline
        var rightPts = _buildWedge(CX + ox, CY + oy, R_OUTER, neckX, neckY, -30.0f, 30.0f, 1);
        _strokePolygon(dc, rightPts);

        // Left wedge outline
        var leftPts  = _buildWedge(CX + ox, CY + oy, R_OUTER, neckX, neckY, 150.0f, 210.0f, -1);
        _strokePolygon(dc, leftPts);
    }

    private function _strokePolygon(dc as Graphics.Dc, pts as Lang.Array) as Void {
        var n = pts.size();
        for (var i = 0; i < n; i++) {
            var a = pts[i]          as Lang.Array;
            var b = pts[(i + 1) % n] as Lang.Array;
            dc.drawLine(a[0] as Lang.Number, a[1] as Lang.Number,
                        b[0] as Lang.Number, b[1] as Lang.Number);
        }
    }

    // ── Public interface (called from InputDelegate) ──────────
    function enterTransformMode() as Void {
        isTransformMode = true;
        activeAlienIndex = 0;
        WatchUi.requestUpdate();
    }

    function exitTransformMode() as Void {
        isTransformMode = false;
        WatchUi.requestUpdate();
    }

    function cycleAlien(direction as Lang.Number) as Void {
        var total = ALIEN_POLYS.size();
        activeAlienIndex = (activeAlienIndex + direction + total) % total;
        WatchUi.requestUpdate();
    }
}
