import { PatternStep } from './PatternStep';

export class HapticPattern {
  name: string;
  steps: PatternStep[];

  constructor(name: string, dsl: string) {
    this.name = name;
    this.steps = PatternStep.parse(dsl);
  }
}

// SOS: · · ·  — — —  · · ·  (short 80 ms, long 240 ms, 80 ms between marks, 240 ms between letters)
const SOS_DSL: string = '[{"vib":80},{"gap":80},{"vib":80},{"gap":80},{"vib":80},{"gap":240},' +
  '{"vib":240},{"gap":80},{"vib":240},{"gap":80},{"vib":240},{"gap":240},' +
  '{"vib":80},{"gap":80},{"vib":80},{"gap":80},{"vib":80}]';

export const PATTERNS: HapticPattern[] = [
  new HapticPattern('Heartbeat', '[{"vib":30},{"gap":100},{"vib":50},{"gap":700},{"vib":30},{"gap":100},{"vib":50}]'),
  new HapticPattern('Notification', '[{"vib":40},{"gap":80},{"vib":40}]'),
  new HapticPattern('Countdown', '[{"vib":60},{"gap":940},{"vib":60},{"gap":940},{"vib":300}]'),
  new HapticPattern('SOS', SOS_DSL)
];
