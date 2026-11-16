import { describe, expect, it } from '@ohos/hypium';
import { HapticPlayer, Semantic } from '../main/ets/haptics/HapticPlayer';
import { PatternSequencer, Scheduler, VibratorDriver } from '../main/ets/haptics/PatternSequencer';
import { PatternStep, StepKind } from '../main/ets/haptics/PatternStep';
import { PATTERNS } from '../main/ets/haptics/Patterns';

class FakeTimer {
  id: number;
  due: number;
  task: () => void;

  constructor(id: number, due: number, task: () => void) {
    this.id = id;
    this.due = due;
    this.task = task;
  }
}

/** A fake clock: timers run only when the test calls advance(). */
class FakeClock {
  now: number = 0;
  private timers: FakeTimer[] = [];
  private nextId: number = 1;

  scheduler(): Scheduler {
    return {
      schedule: (task: () => void, ms: number): number => {
        const timer = new FakeTimer(this.nextId++, this.now + ms, task);
        this.timers.push(timer);
        return timer.id;
      },
      cancel: (id: number): void => {
        this.timers = this.timers.filter((timer: FakeTimer) => timer.id !== id);
      }
    };
  }

  advance(ms: number): void {
    const end = this.now + ms;
    let next = this.nextDue(end);
    while (next !== undefined) {
      const timer = next;
      this.timers = this.timers.filter((t: FakeTimer) => t.id !== timer.id);
      this.now = timer.due;
      timer.task();
      next = this.nextDue(end);
    }
    this.now = end;
  }

  pending(): number {
    return this.timers.length;
  }

  private nextDue(end: number): FakeTimer | undefined {
    let best: FakeTimer | undefined = undefined;
    this.timers.forEach((timer: FakeTimer) => {
      if (timer.due <= end && (best === undefined || timer.due < best.due)) {
        best = timer;
      }
    });
    return best;
  }
}

/** Records the vibrator calls with the fake time. */
class RecordingDriver {
  events: string[] = [];
  private clock: FakeClock;

  constructor(clock: FakeClock) {
    this.clock = clock;
  }

  driver(): VibratorDriver {
    return {
      vibrate: (ms: number): void => {
        this.events.push(`${this.clock.now}:vib${ms}`);
      },
      stop: (): void => {
        this.events.push(`${this.clock.now}:stop`);
      }
    };
  }

  vibrations(): string[] {
    return this.events.filter((event: string) => event.includes('vib'));
  }
}

export default function hapticsTest() {
  describe('PatternStep', () => {
    it('parsesTheDsl', 0, () => {
      const steps = PatternStep.parse('[{"vib":40},{"gap":80},{"vib":200}]');
      expect(steps.length).assertEqual(3);
      expect(steps[1].kind).assertEqual(StepKind.GAP);
      expect(PatternStep.totalMs(steps)).assertEqual(320);
      expect(PatternStep.toDsl(steps)).assertEqual('[{"vib":40},{"gap":80},{"vib":200}]');
    });

    it('rejectsAnInvalidStep', 0, () => {
      let failed = false;
      try {
        PatternStep.parse('[{"vib":40},{"buzz":10}]');
      } catch (err) {
        failed = true;
      }
      expect(failed).assertTrue();
    });

    it('builtInPatternsAreValid', 0, () => {
      expect(PATTERNS.length).assertEqual(4);
      for (const pattern of PATTERNS) {
        expect(pattern.steps.length > 0).assertTrue();
      }
    });
  });

  describe('PatternSequencer', () => {
    it('playsStepsInOrderWithTheRightTiming', 0, () => {
      const clock = new FakeClock();
      const recorder = new RecordingDriver(clock);
      const sequencer = new PatternSequencer(clock.scheduler(), recorder.driver(), () => {});
      sequencer.play(PatternStep.parse('[{"vib":40},{"gap":80},{"vib":200}]'));
      clock.advance(1000);
      expect(recorder.events.join(' ')).assertEqual('0:stop 0:vib40 40:stop 120:stop 120:vib200');
      expect(sequencer.isPlaying()).assertFalse();
    });

    it('reportsTheCurrentStepAndTheEnd', 0, () => {
      const clock = new FakeClock();
      const steps: number[] = [];
      const sequencer = new PatternSequencer(clock.scheduler(), new RecordingDriver(clock).driver(),
        (index: number) => {
          steps.push(index);
        });
      sequencer.play(PatternStep.parse('[{"vib":10},{"gap":10},{"vib":10}]'));
      clock.advance(100);
      expect(steps.join(',')).assertEqual('0,1,2,-1');
    });

    it('cancelStopsTheVibratorAndTheTimers', 0, () => {
      const clock = new FakeClock();
      const recorder = new RecordingDriver(clock);
      const sequencer = new PatternSequencer(clock.scheduler(), recorder.driver(), () => {});
      sequencer.play(PatternStep.parse('[{"vib":100},{"gap":100},{"vib":100}]'));
      clock.advance(50);
      sequencer.cancel();
      clock.advance(1000);
      expect(recorder.vibrations().join(' ')).assertEqual('0:vib100');
      expect(recorder.events[recorder.events.length - 1]).assertEqual('50:stop');
      expect(clock.pending()).assertEqual(0);
    });

    it('newPatternReplacesTheOldOne', 0, () => {
      const clock = new FakeClock();
      const recorder = new RecordingDriver(clock);
      const sequencer = new PatternSequencer(clock.scheduler(), recorder.driver(), () => {});
      sequencer.play(PatternStep.parse('[{"vib":100},{"gap":100},{"vib":100}]'));
      clock.advance(50);
      sequencer.play(PatternStep.parse('[{"vib":30}]'));
      clock.advance(1000);
      // The second vibration of the first pattern never plays.
      expect(recorder.vibrations().join(' ')).assertEqual('0:vib100 50:vib30');
    });
  });

  describe('HapticPlayer', () => {
    it('usesTheFirstSupportedPreset', 0, () => {
      const choice = HapticPlayer.choose(Semantic.SUCCESS, (id: string) => id === 'haptic.effect.sharp', false);
      expect(choice.presetId).assertEqual('haptic.effect.sharp');
      expect(choice.describe()).assertEqual('preset haptic.effect.sharp');
    });

    it('fallsBackToTimeWithoutPresets', 0, () => {
      const choice = HapticPlayer.choose(Semantic.WARNING, () => false, false);
      expect(choice.usesPreset()).assertFalse();
      expect(choice.describe()).assertEqual('time 120 ms');
    });

    it('errorFallbackIsTwoPulses', 0, () => {
      expect(HapticPlayer.choose(Semantic.ERROR, () => false, false).describe()).assertEqual('time 2 × 80 ms');
    });

    it('forceFallbackIgnoresPresets', 0, () => {
      const choice = HapticPlayer.choose(Semantic.TAP, () => true, true);
      expect(choice.describe()).assertEqual('time 20 ms');
    });

    it('presetStopsARunningPattern', 0, () => {
      const clock = new FakeClock();
      const recorder = new RecordingDriver(clock);
      const sequencer = new PatternSequencer(clock.scheduler(), recorder.driver(), () => {});
      const presets: string[] = [];
      const player = new HapticPlayer(sequencer, () => true, (id: string) => {
        presets.push(id);
      });
      player.playPattern(PatternStep.parse('[{"vib":100},{"gap":100},{"vib":100}]'));
      clock.advance(50);
      player.play(Semantic.TAP, false);
      clock.advance(1000);
      expect(presets.join(',')).assertEqual('haptic.effect.soft');
      expect(recorder.vibrations().length).assertEqual(1);
      expect(sequencer.isPlaying()).assertFalse();
    });
  });
}
