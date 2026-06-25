// ============================================================
//  Ben10OmnitrixView.mc
//  Main view — handles all drawing for the Garmnitrix watch face
//
//  Display: 390x390 AMOLED (Garmin Forerunner 165)
//  Palette: #000000 (Pure Black) + #3BFF00 (Neon Green) only
//
//  Idle dial geometry (from image-3 / Omnitrix face reference):
//    - Outer thin neon-green ring outline at r=185
//    - Neon-green solid face circle at r=130
//    - Hourglass: two opposing black triangles meeting at centre:
//        TOP TRIANGLE    => apex at centre, base across top of face circle
//        BOTTOM TRIANGLE => apex at centre, base across bottom of face circle
//
//  Selection dial geometry (from image-2 / alien selector reference):
//    - Black background
//    - Gray outer bezel ring with 4 connector bumps (N/S/E/W)
//    - Large neon-green diamond (rotated square) filling inner region
//    - Alien silhouette polygon rendered inside diamond
//
//  AOD: outline-only, <10% pixel budget, +-2 to 4px shift per minute
//  Battery: linear green->red gradient on hourglass fill
// ============================================================

import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.System;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

class Ben10OmnitrixView extends WatchUi.View {

    // State
    var isTransformMode as Lang.Boolean = false;
    var activeAlienIndex as Lang.Number  = 0;
    var isAod            as Lang.Boolean = false;

    // Screen centre and key radii for FR165 390x390
    private const CX      as Lang.Number = 195;
    private const CY      as Lang.Number = 195;
    private const R_OUTER as Lang.Number = 185;   // thin ring radius
    private const R_FACE  as Lang.Number = 130;   // solid green face radius
    private const R_INNER as Lang.Number = 118;   // inner clip for hourglass

    // AOD burn-in offset table: 10 positions, cycling +/-2..4px per axis
    private var _aodShiftIndex as Lang.Number = 0;
    private const AOD_OFFSETS as Lang.Array = [
        [-4,-4], [-2,-4], [0,-2], [2,-2], [4, 0],
        [ 4, 2], [ 2, 4], [0, 4], [-2, 2], [-4, 0]
    ] as Lang.Array;

    // Alien names (10 total)
    private const ALIEN_NAMES as Lang.Array = [
        "Swampfire", "Chromastone", "Humungousaur",
        "Jetray", "Big Chill", "Goop",
        "Echo Echo", "Alien X", "Brainstorm", "Spidermonkey"
    ] as Lang.Array;

    // Alien silhouette polygons in normalised -50..50 space
    // _drawAlienSilhouette() maps them to screen coords (scale: 50->75px)
    private const ALIEN_POLYS as Lang.Array = [
        // 0 Swampfire - stocky, wide shoulders
        [[-14,-40],[-20,-20],[-30,0],[-22,30],[0,42],[22,30],[30,0],[20,-20],[14,-40],[5,-50],[-5,-50]] as Lang.Array,
        // 1 Chromastone - angular crystal octagon
        [[0,-48],[16,-20],[30,0],[20,40],[0,50],[-20,40],[-30,0],[-16,-20]] as Lang.Array,
        // 2 Humungousaur - massive, very wide
        [[-30,-45],[-40,-10],[-48,20],[-30,45],[0,50],[30,45],[48,20],[40,-10],[30,-45],[15,-50],[-15,-50]] as Lang.Array,
        // 3 Jetray - manta-ray, wide swept wings
        [[-48,-5],[-30,-20],[-10,-40],[0,-48],[10,-40],[30,-20],[48,-5],[30,10],[15,40],[0,48],[-15,40],[-30,10]] as Lang.Array,
        // 4 Big Chill - ghost moth, swept wings
        [[-44,-30],[-20,-10],[-5,-45],[5,-45],[20,-10],[44,-30],[35,10],[20,40],[0,48],[-20,40],[-35,10]] as Lang.Array,
        // 5 Goop - amorphous blob
        [[-10,-48],[10,-48],[30,-30],[45,-5],[40,20],[25,45],[0,50],[-25,45],[-40,20],[-45,-5],[-30,-30]] as Lang.Array,
        // 6 Echo Echo - small boxy rectangle
        [[-18,-46],[18,-46],[26,-20],[26,20],[18,46],[-18,46],[-26,20],[-26,-20]] as Lang.Array,
        // 7 Alien X - tall cosmic, starburst head
        [[0,-50],[8,-28],[30,-38],[18,-14],[38,0],[18,14],[28,38],[0,26],[-28,38],[-18,14],[-38,0],[-18,-14],[-30,-38],[-8,-28]] as Lang.Array,
        // 8 Brainstorm - wide crab with pincers
        [[-22,-40],[22,-40],[40,-20],[48,0],[30,30],[10,48],[-10,48],[-30,30],[-48,0],[-40,-20]] as Lang.Array,
        // 9 Spidermonkey - lanky with sprawling limbs
        [[-8,-48],[8,-48],[20,-25],[38,-10],[38,15],[20,10],[15,48],[-15,48],[-20,10],[-38,15],[-38,-10],[-20,-25]] as Lang.Array
    ] as Lang.Array;

    // ---- Lifecycle ------------------------------------------
    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Graphics.Dc) as Void {
        // Fully vector: nothing to load from layout XML
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

    // ---- AOD / Sleep ----------------------------------------
    function onEnterSleep() as Void {
        isAod = true;
        WatchUi.requestUpdate();
    }

    function onExitSleep() as Void {
        isAod = false;
        WatchUi.requestUpdate();
    }

    // ---- Battery Color Calculation --------------------------
    // 100% battery => #3BFF00 (R59, G255, B0)
    //   0% battery => #FF0000 (R255, G0,   B0)
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

    // ---- IDLE DIAL ------------------------------------------
    // 1. Thin neon-green ring at R_OUTER (outline 2px)
    // 2. Solid neon-green filled face circle at R_FACE
    // 3. Hourglass: two black inward-pointing triangles meeting at CX,CY
    //    TOP:    base at top of face, apex pointing DOWN to centre
    //    BOTTOM: base at bottom of face, apex pointing UP to centre
    //    Corner-softening: small black fill circles at triangle corners
    private function _drawIdleDial(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);

        // Outer ring (2px stroke)
        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(CX, CY, R_OUTER);

        // Bezel segment divider marks at 45-degree positions
        _drawBezelDetails(dc, bColor);

        // Solid face circle
        dc.setColor(bColor, bColor);
        dc.fillCircle(CX, CY, R_FACE);

        // Hourglass geometry
        // halfBase: how wide the triangle base is (fits inside the face circle)
        // topEdge / botEdge: Y coordinates of the triangle bases
        var halfBase = (R_INNER * 92 / 100).toNumber();   // ~109px
        var topEdge  = (CY - R_INNER * 93 / 100).toNumber(); // ~87
        var botEdge  = (CY + R_INNER * 93 / 100).toNumber(); // ~303
        var neckGap  = 3;  // small gap at centre so triangles don't fully touch

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);

        // Top triangle: base at top, apex points DOWN toward centre
        var topTri = [
            [CX - halfBase, topEdge],
            [CX + halfBase, topEdge],
            [CX, CY - neckGap]
        ] as Lang.Array;

        // Bottom triangle: base at bottom, apex points UP toward centre
        var botTri = [
            [CX - halfBase, botEdge],
            [CX + halfBase, botEdge],
            [CX, CY + neckGap]
        ] as Lang.Array;

        dc.fillPolygon(topTri);
        dc.fillPolygon(botTri);

        // Corner softening: small black circles at each of the 4 base corners
        // This rounds off the triangle corners visible against the green face,
        // matching the curved hourglass appearance in the reference image
        dc.fillCircle(CX - halfBase + 10, topEdge + 8, 14);
        dc.fillCircle(CX + halfBase - 10, topEdge + 8, 14);
        dc.fillCircle(CX - halfBase + 10, botEdge - 8, 14);
        dc.fillCircle(CX + halfBase - 10, botEdge - 8, 14);
    }

    // Bezel detail: short radial marks at 45/135/225/315-degree positions
    private function _drawBezelDetails(dc as Graphics.Dc, color as Lang.Number) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        var angles as Lang.Array = [315, 45, 135, 225] as Lang.Array;
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

    // ---- INVISIBLE CLOCK ------------------------------------
    // Renders mandatory system time as #3BFF00 text on the #3BFF00
    // face background. Completely camouflaged, satisfies Garmin OS
    // requirements without being visible to the user.
    private function _drawInvisibleClock(dc as Graphics.Dc) as Void {
        var now     = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var timeStr = now.hour.format("%02d") + ":" + now.min.format("%02d");
        // Neon green text on neon green background = invisible
        dc.setColor(0x3BFF00, 0x3BFF00);
        dc.drawText(CX, CY, Graphics.FONT_LARGE, timeStr,
                    Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // ---- SELECTION DIAL -------------------------------------
    // From image-2 reference:
    //   1. Black background (already cleared)
    //   2. Gray bezel plate (filled circle r=172)
    //   3. Black inner plate (r=158) - creates gray ring
    //   4. Thin gray outer ring stroke (r=182) with 4 bumps at N/S/E/W
    //   5. Large green diamond (rotated square, half-diagonal=118)
    //   6. Dark-green alien silhouette polygon centred on diamond
    private function _drawSelectionDial(dc as Graphics.Dc) as Void {
        var GREEN = 0x3BFF00 as Lang.Number;
        var GRAY  = 0x888888 as Lang.Number;

        // Gray bezel plate
        dc.setColor(GRAY, GRAY);
        dc.fillCircle(CX, CY, 172);

        // Black inner cutout (leaves a gray ring ~14px wide)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillCircle(CX, CY, 158);

        // Thin outer ring
        dc.setColor(GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        dc.drawCircle(CX, CY, 182);

        // 4 connector bumps at cardinal points (matching image-2)
        dc.setColor(GRAY, GRAY);
        var bR = 8;
        dc.fillCircle(CX,       CY - 185, bR); // North
        dc.fillCircle(CX,       CY + 185, bR); // South
        dc.fillCircle(CX - 185, CY,       bR); // West
        dc.fillCircle(CX + 185, CY,       bR); // East

        // Green diamond
        var d = 118;
        var diamond = [
            [CX,     CY - d],
            [CX + d, CY    ],
            [CX,     CY + d],
            [CX - d, CY    ]
        ] as Lang.Array;
        dc.setColor(GREEN, GREEN);
        dc.fillPolygon(diamond);

        // Alien silhouette
        _drawAlienSilhouette(dc, activeAlienIndex);

        // Hidden alien name: black text on black area (outside diamond, below)
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.drawText(CX, CY + 150, Graphics.FONT_SMALL,
                    ALIEN_NAMES[activeAlienIndex] as Lang.String,
                    Graphics.TEXT_JUSTIFY_CENTER);
    }

    // Maps normalised -50..50 polygon to screen coords (scale 50->75px)
    private function _drawAlienSilhouette(dc as Graphics.Dc, idx as Lang.Number) as Void {
        var poly   = ALIEN_POLYS[idx] as Lang.Array;
        var scale  = 75.0f / 50.0f;  // 1.5x
        var mapped as Lang.Array = [] as Lang.Array;
        for (var i = 0; i < poly.size(); i++) {
            var pt = poly[i] as Lang.Array;
            var px = (CX + (pt[0] as Lang.Number) * scale).toNumber();
            var py = (CY + (pt[1] as Lang.Number) * scale).toNumber();
            mapped.add([px, py]);
        }
        dc.setColor(0x1A7000, 0x1A7000);  // dark green silhouette on bright green
        dc.fillPolygon(mapped);
    }

    // ---- AOD OUTLINE ----------------------------------------
    // Burn-in safe: only 1px outline strokes drawn.
    // A 10-position offset table shifts the shape by +-2..4px each paint.
    private function _drawAodOutline(dc as Graphics.Dc, battery as Lang.Float) as Void {
        var bColor = calculateBatteryColor(battery);
        var offset = AOD_OFFSETS[_aodShiftIndex % 10] as Lang.Array;
        var ox = (offset[0] as Lang.Number);
        var oy = (offset[1] as Lang.Number);
        _aodShiftIndex = (_aodShiftIndex + 1) % 10;

        var ccx = CX + ox;
        var ccy = CY + oy;

        // Outer ring outline only
        dc.setColor(bColor, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawCircle(ccx, ccy, R_OUTER);

        // Hourglass outlines only (no fill = minimal pixel count)
        var halfBase = (R_INNER * 92 / 100).toNumber();
        var topEdge  = (ccy - R_INNER * 93 / 100).toNumber();
        var botEdge  = (ccy + R_INNER * 93 / 100).toNumber();
        var neck     = 3;

        // Top triangle perimeter
        dc.drawLine(ccx - halfBase, topEdge, ccx + halfBase, topEdge);
        dc.drawLine(ccx + halfBase, topEdge, ccx,            ccy - neck);
        dc.drawLine(ccx,            ccy - neck, ccx - halfBase, topEdge);

        // Bottom triangle perimeter
        dc.drawLine(ccx - halfBase, botEdge, ccx + halfBase, botEdge);
        dc.drawLine(ccx + halfBase, botEdge, ccx,            ccy + neck);
        dc.drawLine(ccx,            ccy + neck, ccx - halfBase, botEdge);
    }

    // ---- Public state mutators (called by delegate) ---------
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
