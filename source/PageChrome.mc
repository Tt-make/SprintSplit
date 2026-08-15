import Toybox.Graphics;
import Toybox.Lang;

// Shared page furniture so the four pages read as one app: a titled header
// over a rule, section rules between metric groups, and a dot strip showing
// which page of the carousel you are on.
module PageChrome {

    const PAGE_COUNT = 4;

    // A rule inset from the bezel. `widthFactor` is the fraction of the screen
    // width it should span, centred.
    function rule(dc as Graphics.Dc, yFactor as Float, widthFactor as Float) as Void {
        var w = dc.getWidth();
        var y = (dc.getHeight() * yFactor).toNumber();
        var half = (w * widthFactor / 2.0).toNumber();
        dc.setColor(Theme.ACCENT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(w / 2 - half, y, w / 2 + half, y);
    }

    // Divider between two side-by-side metrics.
    function columnRule(dc as Graphics.Dc, topFactor as Float, bottomFactor as Float) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Theme.ACCENT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(w / 2, (h * topFactor).toNumber(), w / 2, (h * bottomFactor).toNumber());
    }

    function header(dc as Graphics.Dc, title as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Theme.ACCENT, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 0.125).toNumber(), Graphics.FONT_XTINY, title,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        rule(dc, 0.185, 0.44);
    }

    // Page position dots along the bottom.
    function pageDots(dc as Graphics.Dc, activeIndex as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var y = (h * 0.945).toNumber();
        var spacing = (w * 0.045).toNumber();
        var startX = w / 2 - (spacing * (PAGE_COUNT - 1)) / 2;

        for (var i = 0; i < PAGE_COUNT; i++) {
            var x = startX + spacing * i;
            if (i == activeIndex) {
                dc.setColor(Theme.ACCENT_SOFT, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 4);
            } else {
                dc.setColor(Theme.ACCENT_DIM, Graphics.COLOR_TRANSPARENT);
                dc.fillCircle(x, y, 3);
            }
        }
    }

    // Small caps label above a value, used for the two-column metric rows.
    function label(dc as Graphics.Dc, xFactor as Float, yFactor as Float, text as String) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Theme.TEXT_DIM, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w * xFactor).toNumber(), (h * yFactor).toNumber(), Graphics.FONT_XTINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function value(dc as Graphics.Dc, xFactor as Float, yFactor as Float, text as String,
                   color as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText((w * xFactor).toNumber(), (h * yFactor).toNumber(), Graphics.FONT_TINY, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function centered(dc as Graphics.Dc, yFactor as Float, text as String,
                      font as Graphics.FontDefinition, color as Number) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * yFactor).toNumber(), font, text,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
