// Rotating Chair Encoder - Thanks Plants / Houseplant hideaway installation
// 2021 francesco.anselmo@gmail.com

#define encoder0PinA  2
#define encoder0PinB  3

const long MAX_POS = 1200;
volatile unsigned long encoder0Pos = MAX_POS/2;

void setup() {
  pinMode(encoder0PinA, INPUT);
  digitalWrite(encoder0PinA, HIGH);       // turn on pull-up resistor
  pinMode(encoder0PinB, INPUT);
  digitalWrite(encoder0PinB, HIGH);       // turn on pull-up resistor

  attachInterrupt(0, doEncoder, CHANGE);  // encoder pin on interrupt 0 - pin 2
  Serial.begin (115200);
  Serial.println(encoder0Pos);                
}

void loop() {
  // No need to do anything here - the joy of interrupts is that they take care of themselves
}

void doEncoder() {
  /* If pinA and pinB are both high or both low, it is spinning
     forward. If they're different, it's going backward.
  */
  if (digitalRead(encoder0PinA) == digitalRead(encoder0PinB)) {
    encoder0Pos++;
     if (encoder0Pos>=MAX_POS) encoder0Pos=0;
  } else {
    encoder0Pos--;
     if (encoder0Pos<=0) encoder0Pos=MAX_POS;
  }

  // Serial.println (encoder0Pos);
  Serial.println (encoder0Pos%MAX_POS, DEC);
}
