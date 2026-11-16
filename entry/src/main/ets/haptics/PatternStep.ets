export enum StepKind {
  VIBRATE = 'vib',
  GAP = 'gap'
}

interface StepJson {
  vib?: number;
  gap?: number;
}

export class PatternStep {
  kind: StepKind;
  ms: number;

  constructor(kind: StepKind, ms: number) {
    this.kind = kind;
    this.ms = ms;
  }

  static vib(ms: number): PatternStep {
    return new PatternStep(StepKind.VIBRATE, ms);
  }

  static gap(ms: number): PatternStep {
    return new PatternStep(StepKind.GAP, ms);
  }

  /**
   * Parses the pattern DSL: a JSON array of {"vib": ms} and {"gap": ms}, for example
   * [{"vib":40},{"gap":80},{"vib":200}]. Throws on an unknown or negative entry.
   */
  static parse(json: string): PatternStep[] {
    const items = JSON.parse(json) as StepJson[];
    return items.map((item: StepJson, index: number) => {
      const vib = item.vib;
      const gap = item.gap;
      if (typeof vib === 'number' && vib > 0) {
        return PatternStep.vib(vib);
      }
      if (typeof gap === 'number' && gap > 0) {
        return PatternStep.gap(gap);
      }
      throw new Error(`Step ${index} must be {"vib": ms} or {"gap": ms} with ms > 0`);
    });
  }

  static toDsl(steps: PatternStep[]): string {
    return `[${steps.map((step: PatternStep) => `{"${step.kind}":${step.ms}}`).join(',')}]`;
  }

  static totalMs(steps: PatternStep[]): number {
    return steps.reduce((sum: number, step: PatternStep) => sum + step.ms, 0);
  }
}
