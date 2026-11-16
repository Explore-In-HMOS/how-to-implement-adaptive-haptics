import { PatternSequencer } from './PatternSequencer';
import { PatternStep, StepKind } from './PatternStep';

export enum Semantic {
  TAP = 'TAP',
  SUCCESS = 'SUCCESS',
  WARNING = 'WARNING',
  ERROR = 'ERROR'
}

export class HapticChoice {
  // The preset to play, or '' for the time-based fallback.
  presetId: string = '';
  fallback: PatternStep[] = [];

  usesPreset(): boolean {
    return this.presetId.length > 0;
  }

  describe(): string {
    if (this.usesPreset()) {
      return `preset ${this.presetId}`;
    }
    const pulses = this.fallback.filter((step: PatternStep) => step.kind === StepKind.VIBRATE);
    return pulses.length === 1 ? `time ${pulses[0].ms} ms` : `time ${pulses.length} × ${pulses[0].ms} ms`;
  }
}

/** Preferred presets for each event, best first. */
export function presetCandidates(semantic: Semantic): string[] {
  switch (semantic) {
    case Semantic.SUCCESS:
      return ['haptic.notice.success', 'haptic.effect.sharp'];
    case Semantic.WARNING:
      return ['haptic.notice.warning', 'haptic.effect.hard'];
    case Semantic.ERROR:
      return ['haptic.notice.fail', 'haptic.effect.hard'];
    default:
      return ['haptic.effect.soft', 'haptic.clock.timer'];
  }
}

/** Time-based vibration when no preset is supported. */
export function fallbackSteps(semantic: Semantic): PatternStep[] {
  switch (semantic) {
    case Semantic.SUCCESS:
      return [PatternStep.vib(40)];
    case Semantic.WARNING:
      return [PatternStep.vib(120)];
    case Semantic.ERROR:
      return [PatternStep.vib(80), PatternStep.gap(60), PatternStep.vib(80)];
    default:
      return [PatternStep.vib(20)];
  }
}

/**
 * Plays semantic feedback (TAP, SUCCESS, WARNING, ERROR) and patterns.
 * The choice is a pure function, so it is unit tested.
 */
export class HapticPlayer {
  private sequencer: PatternSequencer;
  private isSupported: (id: string) => boolean;
  private playPreset: (id: string) => void;

  constructor(sequencer: PatternSequencer, isSupported: (id: string) => boolean, playPreset: (id: string) => void) {
    this.sequencer = sequencer;
    this.isSupported = isSupported;
    this.playPreset = playPreset;
  }

  static choose(semantic: Semantic, isSupported: (id: string) => boolean, forceFallback: boolean): HapticChoice {
    const choice = new HapticChoice();
    if (!forceFallback) {
      const preset = presetCandidates(semantic).find((id: string) => isSupported(id));
      if (preset !== undefined) {
        choice.presetId = preset;
        return choice;
      }
    }
    choice.fallback = fallbackSteps(semantic);
    return choice;
  }

  play(semantic: Semantic, forceFallback: boolean): HapticChoice {
    const choice = HapticPlayer.choose(semantic, this.isSupported, forceFallback);
    if (choice.usesPreset()) {
      // Stop a running pattern first, so the preset does not overlap it.
      this.sequencer.cancel();
      this.playPreset(choice.presetId);
    } else {
      this.sequencer.play(choice.fallback);
    }
    return choice;
  }

  playPattern(steps: PatternStep[]): void {
    this.sequencer.play(steps);
  }

  stopAll(): void {
    this.sequencer.cancel();
  }
}
