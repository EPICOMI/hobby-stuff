// ============================================================
//  Ben10OmnitrixView.mc
//  Main view — handles all drawing for the Garmnitrix watch app
// ============================================================

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Math;

class Ben10OmnitrixView extends WatchUi.View {

    var isTransformMode as Lang.Boolean = false;
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
        // 0 Swampfire
        [[-14,-40],[-20,-20],[-30,0],[-22,30],[0,42],[22,30],[30,0],[20,-20],[14,-40],[5,-50],[-5,-50]] as Lang.Array,
        // 1 Chromastone
        [[0,-48],[16,-20],[30,0],[20,40],[0,50],[-20,40],[-30,0],[-16,-20]] as Lang.Array,
        // 2 Humungousaur
        [[-30,-45],[-40,-10],[-48,20],[-30,45],[0,50],[30,45],[48,20],[40,-10],[30,-45],[15,-50],[-15,-50]] as Lang.Array,
        // 3 Jetray
        [[-48,-5],[-30,-20],[-10,-40],[0,-48],[10,-40],[30,-20],[48,-5],[30,10],[15,40],[0,48],[-15,40],[-30,10]] as Lang.Array,
        // 4 Big Chill
        [[-44,-30],[-20,-10],[-5,-45],[5,-45],[20,-10],[44,-30],[35,10],[20,40],[0,48],[-20,40],[-35,10]] as Lang.Array,
        // 5 Goop
        [[-10,-48],[10,-48],[30,-30],[45,-5],[40,20],[25,45],[0,50],[-25,45],[-40,20],[-45,-5],[-30,-30]] as Lang.Array,
        // 6 Echo Echo
        [[-18,-46],[18,-46],[26,-20],[26,20],[18,46],[-18,46],[-26,20],[-26,-20]] as Lang.Array,
        // 7 Alien X
        [[0,-50],[8,-28],[30,-38],[18,-14],[38,0],[18,14],[28,38],[0,26],[-28,38],[-18,14],[-38,0],[-18,-14],[-30,-38],[-8,-28]] as Lang.Array,
        // 8 Brainstorm
        [[-22,-40],[22,-40],[40,-20],[48,0],[30,30],[10,48],[-10,48],[-30,30],[-48,0],[-40,-20]] as Lang.Array,
        // 9 Spidermonkey
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
        var r = (59 + ((255 - 59) * (100.0f - pct) / 100.0f)).toNumber();
        var g = (255.0f * (pct / 100.0f)).toNumber();
        if (r > 255) { r = 255; }  if (r < 0) { r = 0; }
        if (g > 255) { g = 255; }  if (g < 0) { g = 0; }
        return (r << 16) | (g << 8);
    }

    private function _drawIdleDial(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);

        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(CX, CY, R_OUTER);

        _drawBezelDetails(dc, bColor);

        dc.setColor(bColor, bColor);
        dc.fillCircle(CX, CY, R_FACE);

        var halfBase = (R_INNER * 92 / 100).toNumber();
        var topEdge  = (CY - R_INNER * 93 / 100).toNumber();
        var botEdge  = (CY + R_INNER * 93 / 100).toNumber();
        var neckGap  = 3;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);

        var topTri = [
            [CX - halfBase, topEdge],
            [CX + halfBase, topEdge],
            [CX, CY - neckGap]
        ];

        var botTri = [
            [CX - halfBase, botEdge],
            [CX + halfBase, botEdge],
            [CX, CY + neckGap]
        ];

        dc.fillPolygon(topTri);
        dc.fillPolygon(botTri);

        dc.fillCircle(CX - halfBase + 10, topEdge + 8, 14);
        dc.fillCircle(CX + halfBase - 10, topEdge + 8, 14);
        dc.fillCircle(CX - halfBase + 10, botEdge - 8, 14);
        dc.fillCircle(CX + halfBase - 10, botEdge - 8, 14);
    }

    private function _drawBezelDetails(dc as Graphics.Dc, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var angles = [315, 45, 135, 225];
        for (var i = 0; i < 4; i++) {
            var deg = (angles[i] as Lang.Number).toFloat();
            var rad = deg * 3.14159f / 180.0f;
            var innerR = (R_OUTER - 8).toFloat();
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
        var bR = 8;
        dc.fillCircle(CX,       CY - 185, bR);
        dc.fillCircle(CX,       CY + 185, bR);
        dc.fillCircle(CX - 185, CY,       bR);
        dc.fillCircle(CX + 185, CY,       bR);

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

        var halfBase = (R_INNER * 92 / 100).toNumber();
        var topEdge  = (ccy - R_INNER * 93 / 100).toNumber();
        var botEdge  = (ccy + R_INNER * 93 / 100).toNumber();
        var neck     = 3;

        dc.drawLine(ccx - halfBase, topEdge, ccx + halfBase, topEdge);
        dc.drawLine(ccx + halfBase, topEdge, ccx,            ccy - neck);
        dc.drawLine(ccx,            ccy - neck, ccx - halfBase, topEdge);

        dc.drawLine(ccx - halfBase, botEdge, ccx + halfBase, botEdge);
        dc.drawLine(ccx + halfBase, botEdge, ccx,            ccy + neck);
        dc.drawLine(ccx,            ccy + neck, ccx - halfBase, botEdge);
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
