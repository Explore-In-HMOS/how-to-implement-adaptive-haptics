import { vibrator } from '@kit.SensorServiceKit';

export class PresetEntry {
  id: string;
  supported: boolean = false;

  constructor(id: string) {
    this.id = id;
  }
}

/** Preset effect IDs that the app asks the device about. */
export const PRESET_IDS: string[] = [
  'haptic.clock.timer',
  'haptic.effect.soft',
  'haptic.effect.hard',
  'haptic.effect.sharp',
  'haptic.notice.success',
  'haptic.notice.warning',
  'haptic.notice.fail'
];

/**
 * Asks `vibrator.isSupportEffect` one time for each preset and keeps the
 * answers. An error counts as "not supported".
 */
export class PresetCatalog {
  private entries: PresetEntry[] = PRESET_IDS.map((id: string) => new PresetEntry(id));

  async load(): Promise<PresetEntry[]> {
    for (const entry of this.entries) {
      try {
        entry.supported = await vibrator.isSupportEffect(entry.id);
      } catch (err) {
        entry.supported = false;
      }
    }
    return this.list();
  }

  list(): PresetEntry[] {
    return this.entries.map((entry: PresetEntry) => {
      const copy = new PresetEntry(entry.id);
      copy.supported = entry.supported;
      return copy;
    });
  }

  isSupported(id: string): boolean {
    return this.entries.some((entry: PresetEntry) => entry.id === id && entry.supported);
  }
}
