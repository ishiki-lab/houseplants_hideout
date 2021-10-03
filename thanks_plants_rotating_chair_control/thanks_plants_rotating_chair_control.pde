/* Rotating Chair Control - Thanks Plants / Houseplant hideaway installation
 * 2021 francesco.anselmo@gmail.com
 *
 * Library dependencies:
 * https://motscousus.com/stuff/2011-01_dmxP512/
 * https://github.com/transfluxus/SimpleHTTPServer
 * https://github.com/ddf/Minim
 *
 * The interaction works like this:
 * 1. The program starts in IDLE mode and plays an inviting sound file, triggers the LED lines to no light and brings 
 *    the ambient DMX lights up to a bright level.
 * 2. When the chair rotates significantly (about 60 degrees or more) in either directions, the 10 minutes long sound sequence 
 *    is activated.
 * 3. The 10 minutes long sound sequence starts with three bells, brings the ambient DMX lights to a dim level and activates 
 *    the LED lines to the background level (30% amber gradient - smooth dimming with equal bright and dark - breathing).
 * 4. When, during the 10 minutes long sound sequence, a movement is detected, it activates the LED lines with a 
 *    brighter sequence (250 amber bpm - awake).  
 * 5. If no movement is detected, then the lighting goes back to step 3. The various delays in doing this will create
 *    variance in lighting levels and sequences across.
 * 6. 30 seconds before the 10 minutes long sound sequence ends, there are three bells and the LED lines go into random mode,
 *    while the ambient lighting comes back to a brighter value and the sound does a wind.
 * 7. The program goes again into IDLE mode and restarts.
 */

/*  TODO
 *  1. DMX support for ambient lighting
 */

import processing.serial.*;
import ddf.minim.*;
import processing.net.*;
import http.*;
import java.util.Map;
import dmxP512.*;

DmxP512 dmxOutput;
int universeSize=128;

boolean USE_DMX = false;
boolean USE_SERIAL = true;
boolean USE_HTTP = true;
boolean PLAY_VOICE = true;

int LED_LINES_NUMBER = 6;
float SCALING = 5;
int FONT_SIZE = 20;
int FONT_SIZE_BIG = 30;
int IDLE_TIME = 3*1000;
int MOTION_ANGLE_LIMIT_DEG_IDLE = 90;
int MOTION_ANGLE_LIMIT_DEG_MOTION = 30;
float VOLUME_LEVEL = 0.2;
String AMBIENT_SOUND_FILE_NAME = "thanks_plants_audio.mp3";
String IDLE_SOUND_FILE_NAME = "birdsong.mp3";
String MEDITATION_SOUND_FILE_NAME = "houseplant_hideout_meditation.mp3";
String CHIMES_SOUND_FILE_NAME = "chimes.wav";
int HTTP_DELAY_TIME = 100;
long MAX_POS = 2000;
int SECONDS_FROM_END_TO_IDLE = 50;

Minim minim;

SimpleHTTPServer server;

static abstract class MotionStatus {  
  static final int IDLE = 0;
  static final int RUNNING = 1;
}

static abstract class PlayStatus {
  static final int IDLE = 0;
  static final int PLAYING = 1;
}

class ChimesLEDline {
  String IPAddress;
  String URL;
  String soundFileName;
  AudioPlayer soundFile;
  
  ChimesLEDline (String ip, String sfn) {
    IPAddress = ip;
    soundFileName = sfn;
    soundFile = minim.loadFile(soundFileName, 2048);
    soundFile.setGain(VOLUME_LEVEL);
    soundFile.loop(0);
    soundFile.pause();
  }
  
}

int steps = 1200;
float speed = 0.2;
int motionStatus = MotionStatus.IDLE;
int playStatus = PlayStatus.IDLE;
int prevTime = 0;
int prevStep = 0;
float prevAngle = PI;
float idleAngle = PI;

int lf = 10;      // ASCII linefeed
int selSource = 0;
int newSource = 0;

AudioPlayer ambientSoundFile;
AudioPlayer idleSoundFile;
AudioPlayer meditationSoundFile;
AudioPlayer chimesSoundFile;

Serial encoderPort;  // Create object from Serial class for the Arduino connected Encoder
String val;     // Data received from the serial port
PFont f, fb, ft;

float angle = PI;
float angleDeg = 180;
float angleDegEnd = 180;
float idleAngleDeg = 180;
float percentMovement = 0;
int fading = 255;

PImage img;

String[] chimesFilesNames = {
  "chimes1.wav",
  "chimes2.wav",
  "chimes3.wav",
  "chimes4.wav",
  "chimes5.wav",
  "chimes6.wav"
};

String[] LEDlinesIPAddresses = {
  "192.168.0.21",
  "192.168.0.21",
  "192.168.0.21",
  "192.168.0.21",
  "192.168.0.21",
  "192.168.0.21"
};

//Client[] clients = new Client[LED_LINES_NUMBER];
ChimesLEDline[] chimesLEDlines = new ChimesLEDline[LED_LINES_NUMBER];
//AudioPlayer[] audioPlayers = new AudioPlayer[LED_LINES_NUMBER];

//Client c1;
//Client c2;
//Client c3;
//Client c4;
//Client c5;
//Client c6;

//String data;

void setup() {
  size(800, 600);

  //fullScreen(P2D);

  //fullScreen();
  //fullScreen(P3D);
  //fullScreen(FX2D);

  //noCursor();

  img = loadImage("thanks_plants.png");

  minim = new Minim(this);

  ambientSoundFile = minim.loadFile(AMBIENT_SOUND_FILE_NAME, 2048);
  ambientSoundFile.setGain(VOLUME_LEVEL);
  ambientSoundFile.loop(0);
  ambientSoundFile.pause();

  idleSoundFile = minim.loadFile(IDLE_SOUND_FILE_NAME, 2048);
  idleSoundFile.setGain(VOLUME_LEVEL);
  idleSoundFile.loop();

  meditationSoundFile = minim.loadFile(MEDITATION_SOUND_FILE_NAME, 2048);
  meditationSoundFile.setGain(0);
  meditationSoundFile.mute();
  meditationSoundFile.loop(0);
  meditationSoundFile.pause();

  chimesSoundFile = minim.loadFile(CHIMES_SOUND_FILE_NAME, 2048);
  chimesSoundFile.setGain(0);
  chimesSoundFile.mute();
  chimesSoundFile.loop(0);
  chimesSoundFile.pause();

  // Create the font
  //printArray(PFont.list());
  f = createFont("Helvetica-Light", FONT_SIZE);
  fb = createFont("Helvetica-Light", FONT_SIZE_BIG);
  ft = createFont("Helvetica", FONT_SIZE_BIG*1.5);
  textFont(f);
  fill(255);

  // create LED lines objects
  for (int i=0; i < LED_LINES_NUMBER; i++) {
    chimesLEDlines[i] = new ChimesLEDline(LEDlinesIPAddresses[i], chimesFilesNames[i]);
    
  }
  
  if (USE_DMX) {
    dmxOutput=new DmxP512(this,universeSize,false);
    String dmxPortName = "/dev/ttyUSB0";
    dmxOutput.setupDmxPro(dmxPortName,115200);    
    int nbChannel=16;  
    for(int i=0;i<nbChannel;i++){
      for (int j=0;j<=255;j++) {
        dmxOutput.set(i,j);
        delay(200);
      }
    }
  }

  if (USE_SERIAL) {
    //printArray(Serial.list());
    //String portName = Serial.list()[0]; //change the 0 to a 1 or 2 etc. to match your port
    String portName = "/dev/ttyACM0"; 
    encoderPort = new Serial(this, portName, 115200);
    val = encoderPort.readStringUntil(lf);
  }
  //prevTime = millis();

  // start with both motion status and play status as idle
  motionStatus = MotionStatus.IDLE;
  playStatus = PlayStatus.IDLE;

  if (USE_HTTP) {
    
    println(str(ambientSoundFile.position())+" - "+"LED lines off at start");
    // switch off the LED lines
    for (int i = 0 ; i < LED_LINES_NUMBER ; i++) {
        getHTTP(chimesLEDlines[i].IPAddress,"GET /off HTTP/1.0\r\n");
        getHTTP(chimesLEDlines[i].IPAddress,"GET /gradient HTTP/1.0\r\n");
    }
  }
  
  SimpleHTTPServer.useIndexHtml = true;
  server = new SimpleHTTPServer(this); 
  server.serve("voice_on", "index.html", "setVoiceOn");
  server.serve("voice_off", "index.html", "setVoiceOff");
  server.serve("reset", "index.html", "resetToIdle");
  
}

void setVoiceOn(String uri, HashMap<String, String> parameterMap) {
  println("uri:", uri, "parameters:");
  println(parameterMap);
  PLAY_VOICE = true;
}

void setVoiceOff(String uri, HashMap<String, String> parameterMap) {
  println("uri:", uri, "parameters:");
  println(parameterMap);
  PLAY_VOICE = false;
}

void resetToIdle(String uri, HashMap<String, String> parameterMap) {
  println("uri:", uri, "parameters:");
  println(parameterMap);  
  playStatus = PlayStatus.IDLE;
  ambientSoundFile.rewind();
  ambientSoundFile.pause();
  meditationSoundFile.rewind();
  meditationSoundFile.pause();
  idleSoundFile.rewind();
  idleSoundFile.loop();
  idleSoundFile.play();
  if (USE_HTTP) {
    println(str(ambientSoundFile.position())+" - "+"LED lines off after playing");
    // switch off the LED lines
    for (int i = 0 ; i < LED_LINES_NUMBER ; i++) {
      getHTTP(chimesLEDlines[i].IPAddress,"GET /off HTTP/1.0\r\n");
      getHTTP(chimesLEDlines[i].IPAddress,"GET /gradient HTTP/1.0\r\n");
    }
  }
  if (USE_DMX) {
    int nbChannel=16;  
    for(int i=0;i<nbChannel;i++){
      for (int j=0;j<=255;j++) {
        dmxOutput.set(i,j);
        delay(200);
      }
    }
  }
}


void draw() {
  background(0);
  textAlign(CENTER);
  
  if (PLAY_VOICE == true) meditationSoundFile.unmute();
  else meditationSoundFile.mute();
 
  // converting serial value
  if (USE_SERIAL) {
    try {
      if (val!=null) angle = (Integer.parseInt(val.replace("\r\n", "")))%steps/float(steps)*PI*2;
      //newSource = int((Integer.parseInt(val.replace("\r\n", "")))%steps/float(steps)*videos.length);
      //if (newSource!=selSource) updateVideo(newSource, selSource);
      if (angle != prevAngle) {
        prevTime = millis();
        prevAngle = angle;
      }

      //println("Serial value: "+val+"|"); //print it out in the console
    }
    catch (NumberFormatException e) {
      println("Serial communication value with problem:" +val+"|");
    }
    catch (NullPointerException e) {
      println("Null pointer exception");
    }
  } else {
    //angle = (millis()*speed)%(steps*10)/float(steps*10)*PI*2;
    angle = (mouseX)%(width)/float(width)*PI*2;
    //angle += (mouseX-pmouseX)%(width)/float(width)*PI*2;
    //angle += (mouseX-pmouseX)/float(width)*PI*2;
    if (angle != prevAngle) {
      prevTime = millis();
      prevAngle = angle;
    }
    //newSource = int(angle/PI/2*10000%(steps*10)/float(steps*10)*videos.length);

    //println("Percent movement: "+percentMovement);
  }

  angleDeg = angle/PI*180;
  idleAngleDeg = idleAngle/PI*180;
  //if (selSource < videos.length) angleDegEnd = 360.0/videos.length*(selSource+1);
  //else angleDegEnd = 360.0;
  //float angleDegStart = (360.0/videos.length)*(selSource);
  //percentMovement = (angleDeg-angleDegStart)/(360.0/videos.length)*100;
  //println("New Source: " + newSource + " | Sel Source: " + selSource);
  //if (percentMovement <= 20) fading = int(percentMovement/20*255);
  //if (percentMovement >= 80) fading = int((100-percentMovement)/20*255);
  //if (newSource!=selSource) updateVideo(newSource, selSource);


  //println("Angle: "+angle+"|"); //print it out in the console
  //pushMatrix();

  if (millis()-prevTime > IDLE_TIME ) {
    motionStatus = MotionStatus.IDLE;
    idleAngle = angle;
  }
  else motionStatus = MotionStatus.RUNNING;

  //if (millis()%10==0) println("Angle: "+angle+" | Percent movement: "+percentMovement+" | Angle degrees: "+angleDeg+" | Angle end: "+angleDegEnd);

  //println("Motion: "+motionStatus+" | "+"Playing: "+playStatus+" | "+millis()+" | "+prevTime+" | "+IDLE_TIME+" | "+(millis()-prevTime));

  textFont(f);  
  text("Position: "+str(ambientSoundFile.length()-ambientSoundFile.position()), width/2, height/5.5*5);
  text("Angle: "+str(int(angleDeg - idleAngleDeg)), width/2, height/6*5);
  text("PlayStatus: "+str(playStatus), width/2, height/6.5*5);
  text("MotionStatus: "+str(motionStatus), width/2, height/7*5);
  text("PlayVoice: "+str(PLAY_VOICE), width/2, height/7.5*5);

  /*
   ----------------------------------------------------------
   |                            | MotionStatus | PlayStatus |
   ----------------------------------------------------------
   | Play Idle                  |     IDLE    |     IDLE    | *
   ----------------------------------------------------------
   | Play Ambient + PlayStatus  |   RUNNING   |     IDLE    | *
   ----------------------------------------------------------
   | Play Ambient               |     IDLE    |   PLAYING   |
   ----------------------------------------------------------
   | Play Ambient + Play Chimes |   RUNNING   |   PLAYING   |
   ----------------------------------------------------------
   */

  if (motionStatus == MotionStatus.IDLE && playStatus == PlayStatus.IDLE) {
    tint(255, 255);
    textFont(ft);
    text("Please rotate the chair", width/2, height/5*3);
  } else if (motionStatus == MotionStatus.RUNNING && playStatus == PlayStatus.IDLE) {
    if (abs(angleDeg - idleAngleDeg) > MOTION_ANGLE_LIMIT_DEG_IDLE) playStatus = PlayStatus.PLAYING; 
  } else if (motionStatus == MotionStatus.RUNNING && playStatus == PlayStatus.PLAYING) {

    if (!ambientSoundFile.isPlaying()) {
      idleSoundFile.pause();
      if (USE_DMX) {
        int nbChannel=16;  
        for(int i=0;i<nbChannel;i++){
          for (int j=255;j>=0;j--) {
            dmxOutput.set(i,j);
            delay(200);
          }
        }
      }
      ambientSoundFile.play();
      meditationSoundFile.play();
      if (USE_HTTP) {  
        println(str(ambientSoundFile.position())+" - "+"LED lines awaken");
        // LED lines awaken
        for (int i = 0 ; i < LED_LINES_NUMBER ; i++) {
            getHTTP(chimesLEDlines[i].IPAddress,"GET /awake HTTP/1.0\r\n");
        }

        //getHTTP("192.168.0.21","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.21","GET /random HTTP/1.0\r\n");
        //getHTTP("192.168.0.22","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.22","GET /random HTTP/1.0\r\n");
        //getHTTP("192.168.0.23","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.23","GET /random HTTP/1.0\r\n");
        //getHTTP("192.168.0.24","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.24","GET /random HTTP/1.0\r\n");
        //getHTTP("192.168.0.25","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.25","GET /random HTTP/1.0\r\n");
        //getHTTP("192.168.0.26","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.26","GET /random HTTP/1.0\r\n");

      }
    }
    
    if (!chimesSoundFile.isPlaying() && 
         (abs(angleDeg - idleAngleDeg) > MOTION_ANGLE_LIMIT_DEG_MOTION) &&
         (ambientSoundFile.position()<(ambientSoundFile.length()-SECONDS_FROM_END_TO_IDLE*1000))) {
      chimesSoundFile.rewind();
      chimesSoundFile.play();
      if (USE_HTTP) {  
        println(str(ambientSoundFile.position())+" - "+"LED lines chimes");
        // LED lines chimes
        String sequence = "";
        while (sequence.length()<=2) {
          int r = int(random(0,LED_LINES_NUMBER));
          //print(r);
          if (match(sequence, str(r)) == null) {
            sequence += str(r);
            getHTTP(chimesLEDlines[r].IPAddress,"GET /chimes HTTP/1.0\r\n");
            chimesLEDlines[r].soundFile.rewind();
            chimesLEDlines[r].soundFile.play();
          }
          //println(sequence);
        }
        println(sequence);
        idleAngle = angle;

        //getHTTP("192.168.0.21","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.21","GET /bpm HTTP/1.0\r\n");
        //getHTTP("192.168.0.22","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.22","GET /bpm HTTP/1.0\r\n");
        //getHTTP("192.168.0.23","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.23","GET /bpm HTTP/1.0\r\n");
        //getHTTP("192.168.0.24","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.24","GET /bpm HTTP/1.0\r\n");
        //getHTTP("192.168.0.25","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.25","GET /bpm HTTP/1.0\r\n");
        //getHTTP("192.168.0.26","GET /orange HTTP/1.0\r\n");
        //getHTTP("192.168.0.26","GET /bpm HTTP/1.0\r\n");

        println(str(ambientSoundFile.position())+" - "+"LED lines awaken after chimes");
        // LED lines awaken
        for (int i = 0 ; i < LED_LINES_NUMBER ; i++) {
            getHTTP(chimesLEDlines[i].IPAddress,"GET /awake HTTP/1.0\r\n");
        }

      }
      //idleAngle = angle;
    }

    if (ambientSoundFile.position() >= ambientSoundFile.length()) {
      playStatus = PlayStatus.IDLE;
      ambientSoundFile.rewind();
      ambientSoundFile.pause();
      meditationSoundFile.rewind();
      meditationSoundFile.pause();
    }
    
    //if ((angleDeg >=90.0) && (angleDeg <=270.0)) playStatus = PlayStatus.PLAYING;
    //else if ((angleDeg <90.0) || (angleDeg >270.0)) playStatus = PlayStatus.IDLE;

    int x = width/2;
    int y = height/2;
    translate(x, y);

    noStroke();

    rotate(angle);

    tint(255, fading);
    stroke(255);

    /////////////// Crosshairs //////////////

    int tSize=40;

    image(img, -width/SCALING/2, -height/SCALING*.8, width/SCALING, height/SCALING);

    line(-width/SCALING/2, (-height/SCALING*0.8)-tSize, -width/SCALING/2, (-height/SCALING*0.8)+tSize);
    line((-width/SCALING/2)-tSize, -height/SCALING*0.8, (-width/SCALING/2)+tSize, -height/SCALING*0.8);

    line((-width/SCALING/2) + (width/SCALING), (-height/SCALING*0.8)-tSize, (-width/SCALING/2) + (width/SCALING), (-height/SCALING*0.8)+tSize);
    line((-width/SCALING/2) + (width/SCALING)-tSize, (-height/SCALING*0.8), (-width/SCALING/2) + (width/SCALING)+tSize, (-height/SCALING*0.8));

    line((-width/SCALING/2)-tSize, (-height/SCALING*0.8)+(height/SCALING), (-width/SCALING/2)+tSize, (-height/SCALING*0.8)+(height/SCALING));
    line((-width/SCALING/2), (-height/SCALING*0.8)+(height/SCALING)-tSize, (-width/SCALING/2), (-height/SCALING*0.8)+(height/SCALING)+tSize);

    line((-width/SCALING/2) + (width/SCALING), (-height/SCALING*0.8)+(height/SCALING)-tSize, (-width/SCALING/2) + (width/SCALING), (-height/SCALING*0.8)+(height/SCALING)+tSize);
    line((-width/SCALING/2) + (width/SCALING)-tSize, (-height/SCALING*0.8)+(height/SCALING), (-width/SCALING/2) + (width/SCALING)+tSize, (-height/SCALING*0.8)+(height/SCALING));

    int tempVal=100;
    line(0, tempVal, 0, 200);
    line(0-tSize, tempVal+tSize, 0+tSize, tempVal+tSize);
    noStroke();

    ///////////////////////////////////////////////////////

  }

  /*
   ----------------------------------------------------------
   |                            | MotionStatus | PlayStatus |
   ----------------------------------------------------------
   | Play Idle                  |     IDLE    |     IDLE    | *
   ----------------------------------------------------------
   | Play Ambient + PlayStatus  |   RUNNING   |     IDLE    | *
   ----------------------------------------------------------
   | Play Ambient               |     IDLE    |   PLAYING   |
   ----------------------------------------------------------
   | Play Ambient + Play Chimes |   RUNNING   |   PLAYING   |
   ----------------------------------------------------------
   */

  if (motionStatus == MotionStatus.IDLE && playStatus == PlayStatus.PLAYING ) {
      if (!ambientSoundFile.isPlaying()) {
        idleSoundFile.pause();
        ambientSoundFile.play();
        meditationSoundFile.play();
        if (USE_HTTP) {  
          println(str(ambientSoundFile.position())+" - "+"LED lines awaken while not moving");
          // LED lines awaken
          for (int i = 0 ; i < LED_LINES_NUMBER ; i++) {
            getHTTP(chimesLEDlines[i].IPAddress,"GET /awake HTTP/1.0\r\n");
          }
          //getHTTP("192.168.0.21","GET /orange HTTP/1.0\r\n");
          //getHTTP("192.168.0.21","GET /random HTTP/1.0\r\n");
          //getHTTP("192.168.0.22","GET /orange HTTP/1.0\r\n");
          //getHTTP("192.168.0.22","GET /random HTTP/1.0\r\n");
          //getHTTP("192.168.0.23","GET /orange HTTP/1.0\r\n");
          //getHTTP("192.168.0.23","GET /random HTTP/1.0\r\n");
          //getHTTP("192.168.0.24","GET /orange HTTP/1.0\r\n");
          //getHTTP("192.168.0.24","GET /random HTTP/1.0\r\n");
          //getHTTP("192.168.0.25","GET /orange HTTP/1.0\r\n");
          //getHTTP("192.168.0.25","GET /random HTTP/1.0\r\n");
          //getHTTP("192.168.0.26","GET /orange HTTP/1.0\r\n");
          //getHTTP("192.168.0.26","GET /random HTTP/1.0\r\n");
        }
      }
      if (ambientSoundFile.position() >= ambientSoundFile.length()) {
        playStatus = PlayStatus.IDLE;
        ambientSoundFile.rewind();
        ambientSoundFile.pause();
        meditationSoundFile.rewind();
        meditationSoundFile.pause();
        idleSoundFile.rewind();
        idleSoundFile.loop();
        idleSoundFile.play();
        if (USE_HTTP) {
          println(str(ambientSoundFile.position())+" - "+"LED lines off after playing");
          // switch off the LED lines
          for (int i = 0 ; i < LED_LINES_NUMBER ; i++) {
            getHTTP(chimesLEDlines[i].IPAddress,"GET /off HTTP/1.0\r\n");
            getHTTP(chimesLEDlines[i].IPAddress,"GET /gradient HTTP/1.0\r\n");
          }
        }
        if (USE_DMX) {
          int nbChannel=16;  
          for(int i=0;i<nbChannel;i++){
            for (int j=0;j<=255;j++) {
              dmxOutput.set(i,j);
              delay(200);
            }
          }
        }
      }
  }

}

void serialEvent(Serial encoderPort) {
  val = encoderPort.readStringUntil('\n'); // read it and store it in val
}

String getHTTP(String IP_ADDRESS, String URL) {
  String data="";
  Client c = new Client(this, IP_ADDRESS, 80);
  c.write(URL);
  c.write("\r\n");
  delay(HTTP_DELAY_TIME);
  //if (c.available() > 0) { // If there's incoming data from the client...
  //  data = c.readString(); // ...then grab it and print it
  //}
  return(data);
}

public void keyPressed() {
  if (key == 'V' || key == 'v') {
    PLAY_VOICE = !PLAY_VOICE;
    println("Play Voice: "+PLAY_VOICE);
  } 
}