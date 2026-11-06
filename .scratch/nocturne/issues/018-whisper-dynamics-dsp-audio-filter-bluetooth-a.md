# 018: Whisper Dynamics DSP Audio-Filter & Bluetooth Auto-Disconnect

**What to build:**
DSP Dynamik-Kompression (Ratio 4:1, Attack < 10ms, Limiter -3 dBFS), High-Shelf Filter ab 4.5 kHz (-6 dB) und AudioFocus Freigabe.

**Blocked by:**
TICK-006, TICK-015

**Phase:** Phase 3: Bedtime Engine & Sensorik
**Type:** DSP & Audio | **Layer:** Platform / Audio | **Points:** 5 | **Priority:** P1
**Status:** ready-for-agent

**Acceptance criteria:**
- [ ] Dynamikkompression begrenzt Pegelspitzen von Sprache und Musik auf -3 dBFS.
- [ ] High-Shelf Cut ab 4.5 kHz daempft Zischlaute bei Nachtlautstaerke (5-10%).
- [ ] Nach Ablauf der Grace-Period wird abandonAudioFocus() aufgerufen.
- [ ] Bluetooth-In-Ears wechseln nach Fokusfreigabe selbststaendig in den Standby.

**Verification method:**
Audio Buffer DSP Analysis & AudioFocus Check
