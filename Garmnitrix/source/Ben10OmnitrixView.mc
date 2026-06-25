// ============================================================
//  Ben10OmnitrixView.mc
//  Main view — handles all drawing for the Garmnitrix watch app
//
//  Hourglass geometry (Omniverse-accurate, per spec):
//
//  Each black wedge subtends exactly 60 degrees at the origin.
//  Right wedge: 330 deg to 30 deg  (-30 to +30)
//  Left  wedge: 150 deg to 210 deg
//
//  Green windows: 120 deg top (30-150) and bottom (210-330)
//
//  Flat neck cut: inner tips truncated at x = +/- 0.1*R_FACE
//  so the centre has a clean blocky gap of 0.2*R_FACE wide.
//  Flat tip half-height = 0.05*R_FACE.
//
//  Right wedge polygon (mirrored for left):
//    P1 = outer arc corner at +30 deg  = ( cos30*R,  sin30*R)
//    P2 = outer arc corner at -30 deg  = ( cos30*R, -sin30*R)
//    P3 = inner flat tip bottom        = ( 0.1R,    -0.05R )
//    P4 = inner flat tip top           = ( 0.1R,     0.05R )
// ============================================================

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Math;

class Ben10OmnitrixView extends WatchUi.View {

    var isTransformMode  as Lang.Boolean = false;
    var activeAlienIndex as Lang.Number  = 0;
    var isAod            as Lang.Boolean = false;

    private const CX      as Lang.Number = 195;
    private const CY      as Lang.Number = 195;
    private const R_OUTER as Lang.Number = 185;
    private const R_FACE  as Lang.Number = 130;

    private var _aodShiftIndex as Lang.Number = 0;
    private const AOD_OFFSETS as Lang.Array = [
        [-4,-4], [-2,-4], [0,-2], [2,-2], [4, 0],
        [ 4, 2], [ 2, 4], [0, 4], [-2, 2], [-4, 0]
    ] as Lang.Array;

    private const ALIEN_NAMES as Lang.Array = [
        "Swampfire", "Chromastone", "Humungousaur",
        "Jetray", "Big Chill", "Goop",
        "Echo Echo", "Alien X", "Brainstorm", "Spidermonkey"
    ] as Lang.Array;

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

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
    }

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

    function onEnterSleep() as Void {
        isAod = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        isAod = false;
        WatchUi.requestUpdate();
    }

    function calculateBatteryColor(battery as Lang.Float) as Lang.Number {
        var pct = battery;
        if (pct < 0.0f)   { pct = 0.0f;   }
        if (pct > 100.0f) { pct = 100.0f; }
        var r = (59  + ((255 - 59)  * (100.0f - pct) / 100.0f)).toNumber();
        var g = (255.0f * (pct / 100.0f)).toNumber();
        if (r > 255) { r = 255; } if (r < 0) { r = 0; }
        if (g > 255) { g = 255; } if (g < 0) { g = 0; }
        return (r << 16) | (g << 8);
    }

    // ---- IDLE DIAL ------------------------------------------
    // Builds two black wedge polygons using the 60-degree spec:
    //
    //  cos(30deg) = 0.866,  sin(30deg) = 0.5
    //  Using integer math scaled from R_FACE:
    //    outerX = R_FACE * 866 / 1000
    //    outerY = R_FACE * 500 / 1000
    //    neckX  = R_FACE * 100 / 1000   (0.1 R)
    //    neckY  = R_FACE *  50 / 1000   (0.05R)
    //
    private function _drawIdleDial(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);
        var R = R_FACE;

        // Pre-compute all key coordinates (integer arithmetic only)
        var outerX = R * 866 / 1000;   // cos30 * R  (~112)
        var outerY = R * 500 / 1000;   // sin30 * R  (~65)
        var neckX  = R * 100 / 1000;   // 0.1R       (~13)
        var neckY  = R *  50 / 1000;   // 0.05R      (~6)

        // Outer ring
        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(CX, CY, R_OUTER);

        _drawBezelDetails(dc, bColor);

        // Solid face circle
        dc.setColor(bColor, bColor);
        dc.fillCircle(CX, CY, R);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);

        // RIGHT wedge: spans -30 to +30 degrees
        //   P1 = outer corner at +30 deg = (+outerX, +outerY)  [bottom-right]
        //   P2 = outer corner at -30 deg = (+outerX, -outerY)  [top-right]
        //   P3 = inner flat tip top      = (+neckX,  -neckY)
        //   P4 = inner flat tip bottom   = (+neckX,  +neckY)
        var rightWedge = [
            [CX + outerX, CY + outerY],
            [CX + outerX, CY - outerY],
            [CX + neckX,  CY - neckY],
            [CX + neckX,  CY + neckY]
        ];
        dc.fillPolygon(rightWedge);

        // LEFT wedge: spans 150 to 210 degrees (mirror of right)
        //   P1 = outer corner at 210 deg = (-outerX, +outerY)
        //   P2 = outer corner at 150 deg = (-outerX, -outerY)
        //   P3 = inner flat tip top      = (-neckX,  -neckY)
        //   P4 = inner flat tip bottom   = (-neckX,  +neckY)
        var leftWedge = [
            [CX - outerX, CY + outerY],
            [CX - outerX, CY - outerY],
            [CX - neckX,  CY - neckY],
            [CX - neckX,  CY + neckY]
        ];
        dc.fillPolygon(leftWedge);
    }

    private function _drawBezelDetails(dc as Graphics.Dc, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Tick marks at 0, 90, 180, 270 (right, bottom, left, top)
        var angles = [0, 90, 180, 270];
        for (var i = 0; i < 4; i++) {
            var deg = (angles[i] as Lang.Number).toFloat();
            var rad = deg * 3.14159f / 180.0f;
            var innerR = (R_OUTER - 10).toFloat();
            var x1 = (CX + innerR * Math.cos(rad)).toNumber();
            var y1 = (CY + innerR * Math.sin(rad)).toNumber();
            var x2 = (CX + (R_OUTER + 4).toFloat() * Math.cos(rad)).toNumber();
            var y2 = (CY + (R_OUTER + 4).toFloat() * Math.sin(rad)).toNumber();
            dc.drawLine(x1, y1, x2, y2);
        }
    }

    private function _drawInvisibleClock(dc as Graphics.Dc) as Void {
        var now     = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeStr = now.hour.format("%02d") + ":" + now.min.format("%02d");
        dc.setColor(0x3BFF00, 0x3BFF00);
        dc.drawText(CX, CY, Graphics.FONT_LARGE, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _drawSelectionDial(dc as Graphics.Dc) as Void {
        var GREEN = 0x3BFF00;
        var GRAY  = 0x888888;

        dc.setColor(GRAY, GRAY);
        dc.fillCircle(CX, CY, 172);
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(CX, CY, 158);
        dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(CX, CY, 182);
        dc.setColor(GRAY, GRAY);
        dc.fillCircle(CX,       CY - 185, 8);
        dc.fillCircle(CX,       CY + 185, 8);
        dc.fillCircle(CX - 185, CY,       8);
        dc.fillCircle(CX + 185, CY,       8);

        var d = 118;
        var diamond = [
            [CX,     CY - d],
            [CX + d, CY    ],
            [CX,     CY + d],
            [CX - d, CY    ]
        ];
        dc.setColor(GREEN, GREEN);
        dc.fillPolygon(diamond);

        _drawAlienSilhouette(dc, activeAlienIndex);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, CY + 150, Graphics.FONT_SMALL,
                    ALIEN_NAMES[activeAlienIndex] as Lang.String,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _drawAlienSilhouette(dc as Graphics.Dc, idx as Lang.Number) as Void {
        var poly  = ALIEN_POLYS[idx] as Lang.Array;
        var scale = 75.0f / 50.0f;
        var mapped = [];
        for (var i = 0; i < poly.size(); i++) {
            var pt = poly[i] as Lang.Array;
            var px = (CX + (pt[0] as Lang.Number) * scale).toNumber();
            var py = (CY + (pt[1] as Lang.Number) * scale).toNumber();
            mapped.add([px, py]);
        }
        dc.setColor(0x1A7000, 0x1A7000);
        dc.fillPolygon(mapped);
    }

    private function _drawAodOutline(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);
        var offset = AOD_OFFSETS[_aodShiftIndex % 10] as Lang.Array;
        var ox = offset[0] as Lang.Number;
        var oy = offset[1] as Lang.Number;
        _aodShiftIndex = (_aodShiftIndex + 1) % 10;

        var ccx = CX + ox;
        var ccy = CY + oy;
        var R   = R_FACE;

        var outerX = R * 866 / 1000;
        var outerY = R * 500 / 1000;
        var neckX  = R * 100 / 1000;
        var neckY  = R *  50 / 1000;

        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(ccx, ccy, R_OUTER);

        // Right wedge outline
        dc.drawLine(ccx + outerX, ccy - outerY, ccx + outerX, ccy + outerY);
        dc.drawLine(ccx + outerX, ccy - outerY, ccx + neckX,  ccy - neckY);
        dc.drawLine(ccx + neckX,  ccy - neckY,  ccx + neckX,  ccy + neckY);
        dc.drawLine(ccx + neckX,  ccy + neckY,  ccx + outerX, ccy + outerY);

        // Left wedge outline
        dc.drawLine(ccx - outerX, ccy - outerY, ccx - outerX, ccy + outerY);
        dc.drawLine(ccx - outerX, ccy - outerY, ccx - neckX,  ccy - neckY);
        dc.drawLine(ccx - neckX,  ccy - neckY,  ccx - neckX,  ccy + neckY);
        dc.drawLine(ccx - neckX,  ccy + neckY,  ccx - outerX, ccy + outerY);
    }

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
