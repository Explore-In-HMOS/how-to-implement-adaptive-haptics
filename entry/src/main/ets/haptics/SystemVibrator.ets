import { vibrator } from '@kit.SensorServiceKit';
import { VibratorDriver } from './PatternSequencer';

/**
 * The real vibrator. Calls are not awaited, so pattern timing stays on the
 * setTimeout chain. Errors (no permission, vibration off, device failure)
 * go to `onError`.
 */
export class SystemVibrator {
  private onError: (operation: string, err: Error) => void;
  private attribute: vibrator.VibrateAttribute = { id: 0, usage: 'touch' };

  constructor(onError: (operation: string, err: Error) => void) {
    this.onError = onError;
  }

  driver(): VibratorDriver {
    return {
      vibrate: (ms: number): void => this.vibrate(ms),
      stop: (): void => this.stop()
    };
  }

  vibrate(ms: number): void {
    const effect: vibrator.VibrateTime = { type: 'time', duration: ms };
    this.start(effect, `time ${ms} ms`);
  }

  preset(effectId: string): void {
    this.stop();
    const effect: vibrator.VibratePreset = { type: 'preset', effectId: effectId, count: 1 };
    this.start(effect, `preset ${effectId}`);
  }

  stop(): void {
    try {
      vibrator.stopVibration().catch((err: Error) => this.onError('stopVibration', err));
    } catch (err) {
      this.onError('stopVibration', err as Error);
    }
  }

  private start(effect: vibrator.VibrateEffect, name: string): void {
    try {
      vibrator.startVibration(effect, this.attribute).catch((err: Error) => this.onError(name, err));
    } catch (err) {
      this.onError(name, err as Error);
    }
  }
}
