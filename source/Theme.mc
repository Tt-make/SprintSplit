import Toybox.Graphics;

// Black background with a bright pink accent. Kept in one place so every view
// stays visually consistent.
//
// The values are picked off Garmin's 64-colour palette (each channel is one of
// 00 / 55 / AA / FF): MIP watches such as fenix7 snap any other value to the
// nearest palette entry, which is what turned the earlier 0xCC33FF into a
// purple. Sticking to palette entries keeps the colour identical on both the
// MIP and the AMOLED devices.
module Theme {
    const BG = 0x000000;
    const ACCENT = 0xFF00AA;      // vivid pink, primary accent
    const ACCENT_SOFT = 0xFF55AA; // lighter pink, for live/active values
    const ACCENT_DIM = 0xAA0055;  // deep rose, for rules and axes
    const TEXT = 0xFFFFFF;
    const TEXT_DIM = 0x999999;
}
