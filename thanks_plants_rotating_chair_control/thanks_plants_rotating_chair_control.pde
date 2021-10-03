/* Rotating Chair Control - Thanks Plants installation
 * 2021 francesco.anselmo@gmail.com
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
 *  1. Remove chimes after last bell
 *  2. Different chimes sounds
 *  3. Random choice of chimes and groups when in chimes mode (3 out of 6)
 *  4. DMX support for ambient lighting
 *  5. Encoder check and calibration
 *  6. Lighting transition speed support
 *  7. Web server buttons to enable/disable meditation voice and reset to IDLE
 *  8. Add a minimum angle check when moving in playing mode
 */

import processing.serial.*;
import java.awt.geom.Point2D;
import ddf.minim.*;
import processing.net.*;


boolean USE_SERIAL = true;
boolean USE_HTTP = false;

int NUMBER = 6;
float SCALING = 5;
int FONT_SIZE = 20;
int FONT_SIZE_BIG = 30;
int IDLE_TIME = 3*1000;
int MOTION_ANGLE_LIMIT_DEG = 90;
float VOLUME_LEVEL = 0.2;
String AMBIENT_SOUND_FILE_NAME = "thanks_plants_audio.mp3";
String IDLE_SOUND_FILE_NAME = "birdsong.mp3";
String CHIMES_SOUND_FILE_NAME = "chimes.wav";
int HTTP_DELAY_TIME = 500;

static abstract class MotionStatus {  
  static final int IDLE = 0;
  static final int RUNNING = 1;
}

static abstract class PlayStatus {
  static final int IDLE = 0;
  static final int PLAYING = 1;
}

int steps = 1200;
float speed = 0.2;
int motionStatus = MotionStatus.IDLE;
int playStatus = PlayStatus.IDLE;
int prevTime = 0;
int prevStep = 0;
float prevAngle = 0;
float idleAngle = 0;

int lf = 10;      // ASCII linefeed
int selSource = 0;
int newSource = 0;

Minim minim;
AudioPlayer ambientSoundFile;
AudioPlayer idleSoundFile;
AudioPlayer chimesSoundFile;

Serial myPort;  // Create object from Serial class
String val;     // Data received from the serial port
PFont f, fb, ft;

float angle = 0;
float angleDeg = 0;
float angleDegEnd = 0;
float idleAngleDeg = 0;
float percentMovement = 0;
int fading = 255;

PImage img;

Client c1;
Client c2;
Client c3;
Client c4;
Client c5;
Client c6;
String data;

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
  ambientSoundFile.setVolume(VOLUME_LEVEL);
  ambientSoundFile.loop(0);
  ambientSoundFile.pause();

  idleSoundFile = minim.loadFile(IDLE_SOUND_FILE_NAME, 2048);
  idleSoundFile.setVolume(VOLUME_LEVEL);
  idleSoundFile.loop();

  chimesSoundFile = minim.loadFile(CHIMES_SOUND_FILE_NAME, 2048);
  chimesSoundFile.setVolume(VOLUME_LEVEL);
  chimesSoundFile.loop(0);
  chimesSoundFile.pause();

  // Create the font
  //printArray(PFont.list());
  f = createFont("Helvetica-Light", FONT_SIZE);
  fb = createFont("Helvetica-Light", FONT_SIZE_BIG);
  ft = createFont("Helvetica", FONT_SIZE_BIG*1.5);
  textFont(f);
  fill(255);

  if (USE_SERIAL) {
    printArray(Serial.list());
    String portName = Serial.list()[0]; //change the 0 to a 1 or 2 etc. to match your port
    //String portName = "/dev/ttyACM0"; 
    myPort = new Serial(this, portName, 9600);
    val = myPort.readStringUntil(lf);
  }
  //prevTime = millis();

  // start with both motion status and play status as idle
  motionStatus = MotionStatus.IDLE;
  playStatus = PlayStatus.IDLE;

  if (USE_HTTP) {

    // connect to the ESP 8266 LED lines
    //c1 = new Client(this, "192.168.0.21", 80); // Connect to server on port 80
    //c2 = new Client(this, "192.168.0.22", 80); // Connect to server on port 80
    //c3 = new Client(this, "192.168.0.23", 80); // Connect to server on port 80
    //c4 = new Client(this, "192.168.0.24", 80); // Connect to server on port 80
    //c5 = new Client(this, "192.168.0.25", 80); // Connect to server on port 80
    //c6 = new Client(this, "192.168.0.26", 80); // Connect to server on port 80

    println(str(ambientSoundFile.position())+" - "+"LED lines off at start");
    // switch off the LED lines
    getHTTP("192.168.0.21","GET /off HTTP/1.0\r\n");
    getHTTP("192.168.0.21","GET /sinelon HTTP/1.0\r\n");
    //delay(HTTP_DELAY_TIME);
    getHTTP("192.168.0.22","GET /off HTTP/1.0\r\n");
    getHTTP("192.168.0.22","GET /sinelon HTTP/1.0\r\n");
    //delay(HTTP_DELAY_TIME);
    getHTTP("192.168.0.23","GET /off HTTP/1.0\r\n");
    getHTTP("192.168.0.23","GET /sinelon HTTP/1.0\r\n");
    //delay(HTTP_DELAY_TIME);    
    getHTTP("192.168.0.24","GET /off HTTP/1.0\r\n");
    getHTTP("192.168.0.24","GET /sinelon HTTP/1.0\r\n");
    //delay(HTTP_DELAY_TIME);
    getHTTP("192.168.0.25","GET /off HTTP/1.0\r\n");
    getHTTP("192.168.0.25","GET /sinelon HTTP/1.0\r\n");
    //delay(HTTP_DELAY_TIME);
    getHTTP("192.168.0.26","GET /off HTTP/1.0\r\n");
    getHTTP("192.168.0.26","GET /sinelon HTTP/1.0\r\n");
    //delay(HTTP_DELAY_TIME);    
  }
}

void draw() {
  background(0);
  textAlign(CENTER);
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

      println("Serial value: "+val+"|"); //print it out in the console
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
    if (abs(angleDeg - idleAngleDeg) > MOTION_ANGLE_LIMIT_DEG) playStatus = PlayStatus.PLAYING; 
  } else if (motionStatus == MotionStatus.RUNNING && playStatus == PlayStatus.PLAYING) {

    if (!ambientSoundFile.isPlaying()) {
      idleSoundFile.pause();
      ambientSoundFile.play();
      if (USE_HTTP) {  
        println(str(ambientSoundFile.position())+" - "+"LED lines awaken");
        // LED lines awaken
        getHTTP("192.168.0.21","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.21","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.22","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.22","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.23","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.23","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.24","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.24","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.25","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.25","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.26","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.26","GET /random HTTP/1.0\r\n");

      }
    }
    
    if (!chimesSoundFile.isPlaying()) {
      chimesSoundFile.rewind();
      chimesSoundFile.play();
      if (USE_HTTP) {  
        println(str(ambientSoundFile.position())+" - "+"LED lines chimes");
        // LED lines chimes
        getHTTP("192.168.0.21","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.21","GET /bpm HTTP/1.0\r\n");
        getHTTP("192.168.0.22","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.22","GET /bpm HTTP/1.0\r\n");
        getHTTP("192.168.0.23","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.23","GET /bpm HTTP/1.0\r\n");
        getHTTP("192.168.0.24","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.24","GET /bpm HTTP/1.0\r\n");
        getHTTP("192.168.0.25","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.25","GET /bpm HTTP/1.0\r\n");
        getHTTP("192.168.0.26","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.26","GET /bpm HTTP/1.0\r\n");

        println(str(ambientSoundFile.position())+" - "+"LED lines awaken after chimes");
        // LED lines awaken
        getHTTP("192.168.0.21","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.21","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.22","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.22","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.23","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.23","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.24","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.24","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.25","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.25","GET /random HTTP/1.0\r\n");
        getHTTP("192.168.0.26","GET /orange HTTP/1.0\r\n");
        getHTTP("192.168.0.26","GET /random HTTP/1.0\r\n");

      }
    }

    if (ambientSoundFile.position() >= ambientSoundFile.length()) {
      playStatus = PlayStatus.IDLE;
      ambientSoundFile.rewind();
      ambientSoundFile.pause();
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
        if (USE_HTTP) {  
          println(str(ambientSoundFile.position())+" - "+"LED lines awaken while not moving");
          // LED lines awaken
          getHTTP("192.168.0.21","GET /orange HTTP/1.0\r\n");
          getHTTP("192.168.0.21","GET /random HTTP/1.0\r\n");
          getHTTP("192.168.0.22","GET /orange HTTP/1.0\r\n");
          getHTTP("192.168.0.22","GET /random HTTP/1.0\r\n");
          getHTTP("192.168.0.23","GET /orange HTTP/1.0\r\n");
          getHTTP("192.168.0.23","GET /random HTTP/1.0\r\n");
          getHTTP("192.168.0.24","GET /orange HTTP/1.0\r\n");
          getHTTP("192.168.0.24","GET /random HTTP/1.0\r\n");
          getHTTP("192.168.0.25","GET /orange HTTP/1.0\r\n");
          getHTTP("192.168.0.25","GET /random HTTP/1.0\r\n");
          getHTTP("192.168.0.26","GET /orange HTTP/1.0\r\n");
          getHTTP("192.168.0.26","GET /random HTTP/1.0\r\n");
        }
      }
      if (ambientSoundFile.position() >= ambientSoundFile.length()) {
        playStatus = PlayStatus.IDLE;
        ambientSoundFile.rewind();
        ambientSoundFile.pause();
        idleSoundFile.rewind();
        idleSoundFile.loop();
        idleSoundFile.play();
        if (USE_HTTP) {
          println(str(ambientSoundFile.position())+" - "+"LED lines off after playing");
          // switch off the LED lines
          getHTTP("192.168.0.21","GET /off HTTP/1.0\r\n");
          getHTTP("192.168.0.21","GET /sinelon HTTP/1.0\r\n");
          getHTTP("192.168.0.22","GET /off HTTP/1.0\r\n");
          getHTTP("192.168.0.22","GET /sinelon HTTP/1.0\r\n");
          getHTTP("192.168.0.23","GET /off HTTP/1.0\r\n");
          getHTTP("192.168.0.23","GET /sinelon HTTP/1.0\r\n");
          getHTTP("192.168.0.24","GET /off HTTP/1.0\r\n");
          getHTTP("192.168.0.24","GET /sinelon HTTP/1.0\r\n");
          getHTTP("192.168.0.25","GET /off HTTP/1.0\r\n");
          getHTTP("192.168.0.25","GET /sinelon HTTP/1.0\r\n");
          getHTTP("192.168.0.26","GET /off HTTP/1.0\r\n");
          getHTTP("192.168.0.26","GET /sinelon HTTP/1.0\r\n");
        }
      }
  }

}

void serialEvent(Serial myPort) {
  val = myPort.readStringUntil('\n'); // read it and store it in val
}

String getHTTP(String IP_ADDRESS, String URL) {
  String data="";
  Client c = new Client(this, IP_ADDRESS, 80);;
  c.write(URL);
  c.write("\r\n");
  delay(HTTP_DELAY_TIME);
  //if (c.available() > 0) { // If there's incoming data from the client...
  //  data = c.readString(); // ...then grab it and print it
  //}
  return(data);
}