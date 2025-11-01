// Visual Pulse — Sound-Reactive Neon Ring + Shockwave
// Processing 4  +  processing.sound  (Sketch → Manage Libraries… → install “Sound”)
import processing.sound.*;

//// ----------- AUDIO ----------- ////
// Mic input + level analysis
AudioIn mic;
Amplitude amp;
boolean micOn = true;          // Toggle with key 'M'
float sens = 0.05f;            // Mic threshold (tune with [ and ] keys)

// 16-step step-sequencer / drum demo
int bpm = 100;                 // Change with UP/DOWN arrows
int steps = 16, step = -1;
float stepDurMs;               // Duration of one 1/16 note in milliseconds
int lastStepMillis = 0;
boolean demoBeat = true;       // Toggle with key 'B'

// Drum synthesis (kick = sine osc; snare/hat = white noise + envelopes)
SinOsc     kickOsc;
WhiteNoise snrNoise, hatNoise;
Env        kickEnv, snrEnv, hatEnv;
boolean    kickActive = false;
float      kickFreq = 160;     // Kick starts high, then falls exponentially

//// ----------- VISUALS ----------- ////
// Visual state driven by audio
float pulse = 0;               // 0..1, ring expansion intensity
float shock = 0;               // 0..1 → 0, outward shockwave strength
float baseR;                   // Base radius before pulse scaling
float hueBase = 210;           // Base hue (HSB)

void setup() {
  size(960, 540, P2D);
  smooth(4);
  colorMode(HSB, 360, 100, 100, 100);
  baseR = min(width, height) * 0.22;

  // Mic Input & Amplitude Analyzer
  mic = new AudioIn(this, 0);
  amp = new Amplitude(this);
  if (micOn) { mic.start(); amp.input(mic); }

  // Compute 1/16 step duration from BPM
  updateStepDur();

  // Drum Synth Nodes (Kick / Snare / Hat)
  kickOsc = new SinOsc(this);
  kickEnv = new Env(this);
  snrNoise = new WhiteNoise(this);
  hatNoise = new WhiteNoise(this);
  snrEnv  = new Env(this);
  hatEnv  = new Env(this);

  // Safe Silent Boot (avoid pops/clicks)
  kickOsc.amp(0); kickOsc.play();
  snrNoise.amp(0);
  hatNoise.amp(0);
}

void draw() {
  // Motion-trail background (subtle persistence)
  noStroke(); fill(0, 28); rect(0, 0, width, height);

  // 1) Step Sequencer Advance (if demoBeat is ON)
  if (demoBeat) {
    int now = millis();
    if (now - lastStepMillis >= stepDurMs) {
      lastStepMillis = now;
      step = (step + 1) % steps;  // advance and wrap mod 16
      triggerDrums(step);
    }
  }

  // Kick Pitch Down-Sweep (exponential decay)
  if (kickActive) {
    kickFreq *= 0.92f;           // times-equals 0.92 each frame
    if (kickFreq < 40) kickActive = false;
    kickOsc.freq(kickFreq);
  }

  // 2) Mic Threshold Trigger → Pulse & Shock
  if (micOn) {
    float level = amp.analyze();
    if (level > sens) triggerPulse();
  }

  // 3) Render Ring + Shockwave
  translate(width/2f, height/2f);

  // Gentle hue drift over time; wrap hue mod 360
  float H = (hueBase + 10 * sin(millis()*0.0012f)) % 360;

  // Radius scales with pulse (louder → bigger)
  float r = baseR * (1.0 + 0.35*pulse);

  // Layered neon ring (four strokes with varying alpha/weight)
  noFill();
  for (int i = 0; i < 4; i++){
    float a = map(i, 0, 3, 70, 25);  // outer → inner alpha
    float w = map(i, 0, 3, 20, 4);   // outer → inner stroke weight
    stroke(H, 90, 100, a);
    strokeWeight(w);
    ellipse(0, 0, r*2, r*2);
  }
  // Inner glow
  noStroke();
  fill(H, 70, 100, 35);
  ellipse(0, 0, r*1.35, r*1.35); //<>//

  // Expanding shockwave (maps shock 1→0 into large outer radius)
  if (shock > 0){
    float R = map(shock, 1, 0, r*1.2, max(width, height)*1.25);
    noFill();
    stroke(0, 0, 100, map(shock, 1, 0, 60, 0));
    strokeWeight(6);
    ellipse(0, 0, R, R);
    shock *= 0.94;               // exponential decay
  }

  // Pulse decay (easing)
  pulse *= 0.88;

  // HUD (controls + live parameters)
  resetMatrix();
  fill(0, 0, 100, 80);
  textAlign(LEFT, TOP);
  text("B: Drum "+(demoBeat?"ON":"OFF")+
       "   M: Mic "+(micOn?"ON":"OFF")+
       "   BPM: "+bpm+" (UP/DOWN)"+
       "   Mic Sens: "+nf(sens,1,3)+"  ([ / ])", 12, 12);
}

// Set full-strength pulse & shock on trigger
void triggerPulse(){
  pulse = 1.0;
  shock = 1.0;
}

// Fire instruments on particular steps; also nudge pulse
void triggerDrums(int s){
  if (s == 0 || s == 8)  kick();   // downbeats
  if (s == 4 || s == 12) snare();
  if (s % 2 == 0)        hihat();  // 8ths
  pulse = max(pulse, 0.6);
}

// Kick: sine osc + envelope; pitch drops exponentially
void kick(){
  kickFreq = 160;
  kickOsc.freq(kickFreq);
  kickActive = true;
  // Env.play(object, attack, sustainTime, release, sustainLevel)
  kickEnv.play(kickOsc, 0.001, 0.02, 0.12, 0.9);
}

// Snare: white noise + short envelope
void snare(){
  snrEnv.play(snrNoise, 0.001, 0.02, 0.10, 0.6);
}

// Hi-hat: white noise + even shorter envelope
void hihat(){
  hatEnv.play(hatNoise, 0.001, 0.01, 0.04, 0.35);
}

void keyPressed(){
  // Toggle drum demo
  if (key == 'b' || key == 'B') demoBeat = !demoBeat;

  // Toggle mic input
  if (key == 'm' || key == 'M'){
    micOn = !micOn;
    if (micOn){ mic.start(); amp.input(mic); }
    else       { mic.stop(); }
  }

  // BPM up/down + recompute step duration
  if (keyCode == UP)   { bpm = constrain(bpm + 5, 60, 200); updateStepDur(); }
  if (keyCode == DOWN) { bpm = constrain(bpm - 5, 60, 200); updateStepDur(); }

  // Mic sensitivity fine-tune
  if (key == '[') sens = max(0.005, sens - 0.005);
  if (key == ']') sens = min(0.200, sens + 0.005);
}

// Mouse click also triggers a visual pulse
void mousePressed(){ triggerPulse(); }

// Derive 1/16 note step duration from BPM (60 sec/min ÷ BPM ÷ 4)
void updateStepDur(){
  stepDurMs = 1000f * (60f / bpm / 4f);
}
