// ============================================================
//  Garmnitrix — Ben 10 Omnitrix Watch App for Garmin FR165
//  Entry point: Ben10OmnitrixApp
//  Type: Device App (Watch App) — required for button capture
// ============================================================

import Toybox.Application;
import Toybox.WatchUi;
import Toybox.Lang;

class Ben10OmnitrixApp extends Application.AppBase {

    private var _view    as Ben10OmnitrixView;
    private var _delegate as Ben10InputDelegate;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Lang.Dictionary?) as Void {}

    function onStop(state as Lang.Dictionary?) as Void {}

    function getInitialView() as [ WatchUi.Views ] or [ WatchUi.Views, WatchUi.InputDelegates ] {
        _view     = new Ben10OmnitrixView();
        _delegate = new Ben10InputDelegate(_view);
        return [ _view, _delegate ];
    }
}

function getApp() as Ben10OmnitrixApp {
    return Application.getApp() as Ben10OmnitrixApp;
}
