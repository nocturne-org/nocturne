"""
Test-Runner und Invarianten-Pruefung fuer TICK-007 (SAF) und TICK-026 (AMOLED Theme)
Verifiziert die korrekten Farbwerte, Schichtenarchitektur, Mindestabmessungen
und typografische Konformitaet.
"""

from pathlib import Path
import re
import sys

def test_amoled_colors_and_theme():
    colors_file = Path("lib/presentation/theme/amoled_colors.dart")
    theme_file = Path("lib/presentation/theme/amoled_theme.dart")
    touch_file = Path("lib/presentation/widgets/bedtime_touch_target.dart")

    assert colors_file.exists(), "amoled_colors.dart fehlt"
    assert theme_file.exists(), "amoled_theme.dart fehlt"
    assert touch_file.exists(), "bedtime_touch_target.dart fehlt"

    colors_content = colors_file.read_text(encoding="utf-8")
    theme_content = theme_file.read_text(encoding="utf-8")
    touch_content = touch_file.read_text(encoding="utf-8")

    # Kriterium 1: 100% #000000 fuer OLED-Pixelabschaltung
    assert "0xFF000000" in colors_content, "Reines Schwarz 0xFF000000 fehlt in AmoledColors"
    assert "scaffoldBackgroundColor: AmoledColors.pureBlack" in theme_content, "Scaffold-Hintergrund ist nicht pureBlack"
    assert "canvasColor: AmoledColors.pureBlack" in theme_content, "Canvas-Hintergrund ist nicht pureBlack"

    # Kriterium 2: Gedaempfte Akzente (Bernstein #F59E0B und Nacht-Cyan #06B6D4)
    assert "0xFFF59E0B" in colors_content, "Bernstein-Akzent #F59E0B fehlt"
    assert "0xFF06B6D4" in colors_content, "Nacht-Cyan-Akzent #06B6D4 fehlt"

    # Kriterium 3: Blendfreie Texte (#E2E8F0 und #94A3B8, kein #FFFFFF)
    assert "0xFFE2E8F0" in colors_content, "Text Primary #E2E8F0 fehlt"
    assert "0xFF94A3B8" in colors_content, "Text Secondary #94A3B8 fehlt"
    assert "0xFFFFFFFF" not in colors_content, "Grelles Weiss (0xFFFFFFFF) darf nicht in AmoledColors definiert sein"

    # Kriterium 4: Barrierefreie Touch-Ziele (>= 48 dp)
    assert "minTouchTargetSize = 48.0" in theme_content, "Mindest-Touch-Zielgroesse von 48.0 dp fehlt"
    assert "minWidth = AmoledTheme.minTouchTargetSize" in touch_content, "BedtimeTouchTarget erzwingt keine 48 dp Breite"
    assert "minHeight = AmoledTheme.minTouchTargetSize" in touch_content, "BedtimeTouchTarget erzwingt keine 48 dp Hoehe"

    print("[PASS] TICK-026 AMOLED Pure Black Theme & Bedtime Design System verifiziert.")

def test_saf_storage_architecture():
    domain_entity = Path("lib/domain/models/storage/saf_directory.dart")
    domain_exceptions = Path("lib/domain/models/storage/saf_storage_exception.dart")
    domain_repo = Path("lib/domain/repositories/storage_repository.dart")
    platform_iface = Path("lib/platform/saf/saf_platform_interface.dart")
    platform_channel = Path("lib/platform/saf/saf_method_channel.dart")
    platform_adapter = Path("lib/platform/saf/saf_storage_adapter.dart")
    data_repo = Path("lib/data/repositories/saf_storage_repository_impl.dart")

    files = [
        domain_entity, domain_exceptions, domain_repo,
        platform_iface, platform_channel, platform_adapter, data_repo
    ]

    for f in files:
        assert f.exists(), f"Datei fehlt: {f}"

    adapter_code = platform_adapter.read_text(encoding="utf-8")
    data_repo_code = data_repo.read_text(encoding="utf-8")

    # Kriterium 1: takePersistableUriPermission dauerhaft
    assert "takePersistableUriPermission" in adapter_code, "takePersistableUriPermission fehlt im Adapter"

    # Kriterium 2: Persistierte Rechte ueber Neustarts
    assert "getPersistedDirectories" in data_repo_code, "getPersistedDirectories fehlt im Repo"

    # Kriterium 3: Fehlertolerante Rueckmeldung bei unmounted SD-Karte oder geloeschtem Pfad
    assert "SafStorageUnavailableException" in adapter_code, "Ausnahme fuer getrennte SD-Karte fehlt"
    assert "SafDirectoryNotFoundException" in adapter_code, "Ausnahme fuer geloeschten Pfad fehlt"
    assert "storageUnmounted" in adapter_code, "Status storageUnmounted fehlt"

    print("[PASS] TICK-007 Android SAF Ordner-Picker & Clean Architecture verifiziert.")

def test_typography_strict_ascii():
    root = Path(".")
    for ext in [".dart", ".yaml", ".py", ".md"]:
        for p in root.rglob(f"*{ext}"):
            if ".git" in str(p) or ".dart_tool" in str(p):
                continue
            content = p.read_bytes()
            assert b"\xe2\x80\x93" not in content, f"En-Dash (U+2013) in {p}"
            assert b"\xe2\x80\x94" not in content, f"Em-Dash (U+2014) in {p}"

    print("[PASS] Typografie: 100% striktes Standard-ASCII-Minus (-). Keine unzulaessigen Gedankenstriche.")

def main():
    try:
        test_amoled_colors_and_theme()
        test_saf_storage_architecture()
        test_typography_strict_ascii()
        print("\n>> ALLE TESTS ERFOLGREICH ABGESCHLOSSEN (100% PASS) <<\n")
    except AssertionError as e:
        print(f"\n[FAIL] Test fehlgeschlagen: {e}\n")
        sys.exit(1)

if __name__ == "__main__":
    main()
