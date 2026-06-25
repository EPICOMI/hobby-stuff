// ============================================================
//  Ben10OmnitrixView.mc
//  Main view — handles all drawing for the Garmnitrix watch app
//
//  Hourglass geometry (corrected):
//    LEFT triangle:  vertical base on LEFT edge of face circle,
//                    apex pointing RIGHT toward centre
//    RIGHT triangle: vertical base on RIGHT edge of face circle,
//                    apex pointing LEFT toward centre
//    Result: two inward-pointing black wedges from left & right,
//            leaving the classic Omnitrix hourglass negative space.
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
    private const R_INNER as Lang.Number = 118;

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
    // Hourglass = two black triangles pointing INWARD from LEFT and RIGHT:
    //
    //   LEFT triangle:
    //     base = vertical line at leftEdge (CX - R_INNER)
    //     top-left corner  = [leftEdge, CY - halfH]
    //     bot-left corner  = [leftEdge, CY + halfH]
    //     apex             = [CX - neckGap, CY]   (points RIGHT toward centre)
    //
    //   RIGHT triangle (mirror):
    //     base = vertical line at rightEdge (CX + R_INNER)
    //     top-right corner = [rightEdge, CY - halfH]
    //     bot-right corner = [rightEdge, CY + halfH]
    //     apex             = [CX + neckGap, CY]   (points LEFT toward centre)
    //
    private function _drawIdleDial(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);

        // Outer ring
        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(CX, CY, R_OUTER);

        _drawBezelDetails(dc, bColor);

        // Solid face circle
        dc.setColor(bColor, bColor);
        dc.fillCircle(CX, CY, R_FACE);

        // Hourglass wedge geometry
        var leftEdge  = CX - R_INNER;          // x of left base
        var rightEdge = CX + R_INNER;          // x of right base
        var halfH     = R_INNER * 90 / 100;    // half-height of base (~106px)
        var neckGap   = 4;                     // gap between apexes at centre

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);

        // LEFT wedge: base on left, apex points right
        var leftTri = [
            [leftEdge, CY - halfH],
            [leftEdge, CY + halfH],
            [CX - neckGap, CY]
        ];
        dc.fillPolygon(leftTri);

        // RIGHT wedge: base on right, apex points left
        var rightTri = [
            [rightEdge, CY - halfH],
            [rightEdge, CY + halfH],
            [CX + neckGap, CY]
        ];
        dc.fillPolygon(rightTri);

        // Corner-softening circles at each base corner
        // Rounds off the sharp triangle corners against the green face
        dc.fillCircle(leftEdge  + 10, CY - halfH + 10, 16);
        dc.fillCircle(leftEdge  + 10, CY + halfH - 10, 16);
        dc.fillCircle(rightEdge - 10, CY - halfH + 10, 16);
        dc.fillCircle(rightEdge - 10, CY + halfH - 10, 16);
    }

    private function _drawBezelDetails(dc as Graphics.Dc, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        // Tick marks at top, bottom, left, right (0, 90, 180, 270 degrees)
        var angles = [270, 90, 180, 0];
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
        // Neon green text on neon green fill = invisible to user
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

        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(ccx, ccy, R_OUTER);

        var leftEdge  = ccx - R_INNER;
        var rightEdge = ccx + R_INNER;
        var halfH     = R_INNER * 90 / 100;
        var neck      = 4;

        // Left wedge outline
        dc.drawLine(leftEdge, ccy - halfH, leftEdge,   ccy + halfH);
        dc.drawLine(leftEdge, ccy - halfH, ccx - neck, ccy);
        dc.drawLine(leftEdge, ccy + halfH, ccx - neck, ccy);

        // Right wedge outline
        dc.drawLine(rightEdge, ccy - halfH, rightEdge,  ccy + halfH);
        dc.drawLine(rightEdge, ccy - halfH, ccx + neck, ccy);
        dc.drawLine(rightEdge, ccy + halfH, ccx + neck, ccy);
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
