import { BusinessError } from '@kit.BasicServicesKit';
import { Constants } from '../common/Constants';
import { LogEntry, Logger, LogLevel } from '../common/Logger';
import { HapticPlayer, Semantic } from '../haptics/HapticPlayer';
import { PatternSequencer, TIMER_SCHEDULER } from '../haptics/PatternSequencer';
import { PatternStep, StepKind } from '../haptics/PatternStep';
import { HapticPattern, PATTERNS } from '../haptics/Patterns';
import { PresetCatalog, PresetEntry } from '../haptics/PresetCatalog';
import { SystemVibrator } from '../haptics/SystemVibrator';

const SEMANTICS: Semantic[] = [Semantic.TAP, Semantic.SUCCESS, Semantic.WARNING, Semantic.ERROR];

@Entry
@Component
struct Index {
  @State presets: PresetEntry[] = [];
  @State presetsLoaded: boolean = false;
  @State lastUsed: string = '';
  @State forceFallback: boolean = false;
  @State patternIndex: number = 0;
  @State currentStep: number = -1;
  @State vibrationFailed: boolean = false;
  @State logs: LogEntry[] = [];

  private catalog: PresetCatalog = new PresetCatalog();
  private vibrator: SystemVibrator = new SystemVibrator((operation: string, err: Error) =>
    this.onVibrationError(operation, err));
  private sequencer: PatternSequencer = new PatternSequencer(TIMER_SCHEDULER, this.vibrator.driver(),
    (index: number) => {
      this.currentStep = index;
    });
  private player: HapticPlayer = new HapticPlayer(this.sequencer, (id: string) => this.catalog.isSupported(id),
    (id: string) => this.vibrator.preset(id));

  aboutToAppear(): void {
    this.catalog.load().then((entries: PresetEntry[]) => {
      this.presets = entries;
      this.presetsLoaded = true;
      const supported = entries.filter((entry: PresetEntry) => entry.supported).length;
      this.addLog(`Preset support: ${supported}/${entries.length}`);
    });
  }

  onPageHide(): void {
    this.stopAll('page hidden');
  }

  aboutToDisappear(): void {
    this.player.stopAll();
  }

  // ---------- Actions ----------

  private playSemantic(semantic: Semantic): void {
    const choice = this.player.play(semantic, this.forceFallback);
    this.lastUsed = choice.describe();
    this.addLog(`${semantic}: ${this.lastUsed}`);
  }

  private playPattern(): void {
    const pattern = PATTERNS[this.patternIndex];
    const interrupted = this.sequencer.isPlaying();
    this.player.playPattern(pattern.steps);
    this.lastUsed = `pattern ${pattern.name}`;
    this.addLog(`Pattern ${pattern.name}: ${pattern.steps.length} steps, ` +
      `${PatternStep.totalMs(pattern.steps)} ms${interrupted ? ' (previous pattern stopped)' : ''}`);
  }

  private stopAll(reason: string): void {
    if (this.sequencer.isPlaying()) {
      this.addLog(`Stopped: ${reason}`);
    }
    this.player.stopAll();
    this.vibrator.stop();
  }

  private onVibrationError(operation: string, err: Error): void {
    const code = (err as BusinessError).code;
    this.vibrationFailed = true;
    this.addLog(`${operation} failed: code ${code} ${err.message}`, LogLevel.ERROR);
  }

  private addLog(message: string, level: LogLevel = LogLevel.INFO): void {
    const entry = Logger.log(message, level);
    this.logs = [entry, ...this.logs].slice(0, Constants.LOG_LIMIT);
  }

  // ---------- View helpers ----------

  private semanticColor(semantic: Semantic): ResourceColor {
    switch (semantic) {
      case Semantic.SUCCESS:
        return $r('app.color.success');
      case Semantic.WARNING:
        return $r('app.color.warning');
      case Semantic.ERROR:
        return $r('app.color.error');
      default:
        return $r('app.color.accent');
    }
  }

  private supportedCount(): number {
    return this.presets.filter((entry: PresetEntry) => entry.supported).length;
  }

  private logColor(level: LogLevel): ResourceColor {
    switch (level) {
      case LogLevel.ERROR:
        return $r('app.color.error');
      case LogLevel.WARN:
        return $r('app.color.warning');
      default:
        return '#AEAEB2';
    }
  }

  // ---------- Layout ----------

  @Builder
  feedbackButtons() {
    Grid() {
      ForEach(SEMANTICS, (semantic: Semantic) => {
        GridItem() {
          Button(semantic)
            .width('100%')
            .height(40)
            .fontSize(13)
            .fontColor(Color.Black)
            .backgroundColor(this.semanticColor(semantic))
            .onClick(() => this.playSemantic(semantic))
        }
      }, (semantic: Semantic) => semantic)
    }
    .columnsTemplate('1fr 1fr')
    .columnsGap(6)
    .rowsGap(6)
    .width('76%')
    .height(86)
  }

  @Builder
  patternStrip() {
    // Each step is as wide as its duration; the step that plays now is orange.
    Row() {
      ForEach(PATTERNS[this.patternIndex].steps, (step: PatternStep, index: number) => {
        Column()
          .layoutWeight(step.ms)
          .height(step.kind === StepKind.VIBRATE ? 14 : 2)
          .borderRadius(2)
          .backgroundColor(index === this.currentStep ? $r('app.color.warning') :
            (step.kind === StepKind.VIBRATE ? $r('app.color.accent') : '#3A3A3C'))
      }, (step: PatternStep, index: number) => `${this.patternIndex}-${index}`)
    }
    .width('76%')
    .height(16)
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Scroll() {
      Column({ space: 6 }) {
        Text($r('app.string.title'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
        Text(this.presetsLoaded ? `Preset support ${this.supportedCount()}/${this.presets.length}` : 'Checking presets…')
          .fontSize(12)
          .fontColor($r('app.color.neutral'))

        if (this.vibrationFailed) {
          Text($r('app.string.banner_vibration_failed'))
            .width('76%')
            .padding(8)
            .fontSize(12)
            .fontColor(Color.Black)
            .textAlign(TextAlign.Center)
            .borderRadius(12)
            .backgroundColor($r('app.color.warning'))
            .onClick(() => {
              this.vibrationFailed = false;
            })
        }

        Text($r('app.string.feedback'))
          .fontSize(13)
          .fontColor($r('app.color.neutral'))
        this.feedbackButtons()
        Text(this.lastUsed.length > 0 ? `Used: ${this.lastUsed}` : ' ')
          .width('76%')
          .fontSize(12)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)

        Row() {
          Text($r('app.string.force_fallback'))
            .fontSize(14)
            .fontColor(Color.White)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.forceFallback })
            .selectedColor($r('app.color.warning'))
            .onChange((isOn: boolean) => {
              this.forceFallback = isOn;
              this.addLog(`Force fallback ${isOn ? 'ON' : 'OFF'}`);
            })
        }
        .width('78%')
        .height(40)

        Text($r('app.string.patterns'))
          .fontSize(13)
          .fontColor($r('app.color.neutral'))
          .margin({ top: 4 })
        Grid() {
          ForEach(PATTERNS, (pattern: HapticPattern, index: number) => {
            GridItem() {
              Button(pattern.name)
                .width('100%')
                .height(34)
                .fontSize(12)
                .backgroundColor(index === this.patternIndex ? $r('app.color.accent') : $r('app.color.card'))
                .onClick(() => {
                  this.patternIndex = index;
                })
            }
          }, (pattern: HapticPattern) => pattern.name)
        }
        .columnsTemplate('1fr 1fr')
        .columnsGap(6)
        .rowsGap(6)
        .width('76%')
        .height(74)

        this.patternStrip()
        Row({ space: 8 }) {
          Button($r('app.string.btn_play'))
            .height(40)
            .layoutWeight(1)
            .fontSize(15)
            .backgroundColor($r('app.color.success'))
            .onClick(() => this.playPattern())
          Button($r('app.string.btn_stop'))
            .height(40)
            .layoutWeight(1)
            .fontSize(15)
            .backgroundColor($r('app.color.card'))
            .onClick(() => this.stopAll('Stop button'))
        }
        .width('72%')
        Text(PatternStep.toDsl(PATTERNS[this.patternIndex].steps))
          .width('76%')
          .fontSize(9)
          .fontColor($r('app.color.neutral'))
          .wordBreak(WordBreak.BREAK_ALL)

        Text($r('app.string.preset_support'))
          .fontSize(13)
          .fontColor($r('app.color.neutral'))
          .margin({ top: 6 })
        ForEach(this.presets, (entry: PresetEntry) => {
          Row() {
            Text(entry.id)
              .fontSize(12)
              .fontColor(Color.White)
              .layoutWeight(1)
            Text(entry.supported ? '✓' : '✗')
              .fontSize(14)
              .fontColor(entry.supported ? $r('app.color.success') : $r('app.color.error'))
          }
          .width('76%')
          .height(22)
        }, (entry: PresetEntry) => `${entry.id}-${entry.supported}`)

        Text($r('app.string.event_log'))
          .fontSize(13)
          .fontColor($r('app.color.neutral'))
          .margin({ top: 6 })
        ForEach(this.logs, (entry: LogEntry) => {
          Text(`${entry.time}  ${entry.message}`)
            .width('76%')
            .fontSize(11)
            .fontColor(this.logColor(entry.level))
        }, (entry: LogEntry) => entry.id.toString())
      }
      .width('100%')
      .padding({ top: 40, bottom: 56 })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .backgroundColor(Color.Black)
  }
}
