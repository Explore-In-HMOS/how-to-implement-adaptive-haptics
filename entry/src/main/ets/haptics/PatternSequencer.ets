import { PatternStep, StepKind } from './PatternStep';

/** Timer access, so that tests can use a fake clock. */
export interface Scheduler {
  schedule: (task: () => void, ms: number) => number;
  cancel: (id: number) => void;
}

/** The vibrator, so that tests can record the calls. */
export interface VibratorDriver {
  vibrate: (ms: number) => void;
  stop: () => void;
}

export const TIMER_SCHEDULER: Scheduler = {
  schedule: (task: () => void, ms: number): number => setTimeout(task, ms),
  cancel: (id: number): void => clearTimeout(id)
};

/**
 * Plays a composite pattern with chained setTimeout calls. Each step first
 * stops the vibrator and then starts its own vibration (or stays quiet for
 * a gap). A new pattern cancels the old one at once: its pending timer is
 * cleared, so two patterns never overlap.
 */
export class PatternSequencer {
  private scheduler: Scheduler;
  private driver: VibratorDriver;
  private steps: PatternStep[] = [];
  private index: number = -1;
  private timerId: number = -1;
  private onStep: (index: number) => void;

  constructor(scheduler: Scheduler, driver: VibratorDriver, onStep: (index: number) => void) {
    this.scheduler = scheduler;
    this.driver = driver;
    this.onStep = onStep;
  }

  isPlaying(): boolean {
    return this.index >= 0;
  }

  play(steps: PatternStep[]): void {
    this.cancel();
    if (steps.length === 0) {
      return;
    }
    this.steps = steps;
    this.runStep(0);
  }

  /** Stops the pattern and the vibrator. `onStep(-1)` reports the end. */
  cancel(): void {
    if (this.timerId !== -1) {
      this.scheduler.cancel(this.timerId);
      this.timerId = -1;
    }
    if (this.index >= 0) {
      this.driver.stop();
      this.index = -1;
      this.onStep(-1);
    }
  }

  private runStep(index: number): void {
    if (index >= this.steps.length) {
      this.timerId = -1;
      this.index = -1;
      this.onStep(-1);
      return;
    }
    this.index = index;
    const step = this.steps[index];
    this.driver.stop();
    if (step.kind === StepKind.VIBRATE) {
      this.driver.vibrate(step.ms);
    }
    this.onStep(index);
    this.timerId = this.scheduler.schedule(() => this.runStep(index + 1), step.ms);
  }
}
