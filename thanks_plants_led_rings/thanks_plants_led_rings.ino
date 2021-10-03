/*
 * LED rings lighting - Thanks Plants installation
 * 2021 francesco.anselmo@gmail.com
 * ESP8266 + WS2812 lighting control for a DaeWha Kang Installation
 *
 * Dependencies
 * ESP8266 board manager library
 * FastLED
 *
 * Rings
 * no  leds  ip
 * 1   200   192.168.1.21 
 * 2   200   192.168.1.22 
 * 3   200   192.168.1.23 
 * 4   200   192.168.1.24  
 * 5   200   192.168.1.25  
 * 6   200   192.168.1.26 
 *
 */

/*  TODO
 *  1. Add Access Point mode
 *  2. Lighting transition speed support
 */


#define IP_ADDRESS 26 // last number of IP address
#define NODE_NAME "tp6"
#define NUM_LEDS   200

#include <ESP8266WiFi.h>
#include <WiFiClient.h>
#include <ESP8266WebServer.h>
#include <ESP8266mDNS.h>

#include "FastLED.h"

FASTLED_USING_NAMESPACE

#if defined(FASTLED_VERSION) && (FASTLED_VERSION < 3001000)
#warning "Requires FastLED 3.1 or later; check github for latest code."
#endif

#define DATA_PIN    4
//#define CLK_PIN   4
#define LED_TYPE    WS2812
#define COLOR_ORDER RGB
#define DELAY 20
CRGB leds[NUM_LEDS];
CRGBPalette16 palette = PartyColors_p;

int transition = 3;
int brightness = 150;
int reset_time = 1*60*60*1000;

//#define BRIGHTNESS          96
#define FRAMES_PER_SECOND  100
 
const char *ssid = "ThanksPlants2";
const char *password = "75189501"; // change to real password
 
MDNSResponder mdns;
ESP8266WebServer server ( 80 );
const int led = 13;
uint8_t idx = 0; // rotating index


DEFINE_GRADIENT_PALETTE( aiml_gp ) {
  0,     0,  0,  0,   //black
  50,     0,  0,  255,   //blue
  100,     0,  255,  255,   //cyan
  255,     255,  255,  255,   //white
};

DEFINE_GRADIENT_PALETTE( pm_gp ) {
  0,     0,  255,  0,   //green
  100,     255,  255,  0,   //yellow
  200,     255,  0,  0,   //red
  255,     255,  0,  128,   //pink
};

DEFINE_GRADIENT_PALETTE( blue_gp ) {
  0,     0,  0,  0,   //black
255,     0,  0,  255 }; //blue

DEFINE_GRADIENT_PALETTE( green_gp ) {
  0,     0,  0,  0,   //black
255,     0,  255,  0 }; //green

DEFINE_GRADIENT_PALETTE( yellow_gp ) {
  0,     0,  0,  0,   //black
255,     255,  255,  0 }; //yellow

DEFINE_GRADIENT_PALETTE( orange_gp ) {
  0,     0,  0,  0,   //black
  10,     10,  5,  0,   
  20,     20,  10,  0,   
  200,     200,  100,  0,
255,     255, 128,  0 }; //orange

DEFINE_GRADIENT_PALETTE( red_gp ) {
  0,     0,  0,  0,   //black
255,     255,  0,  0 }; //red

DEFINE_GRADIENT_PALETTE( pink_gp ) {
  0,     0,  0,  0,   //black
255,     255,  0,  128 }; //pink

DEFINE_GRADIENT_PALETTE( white_gp ) {
  0,     0,  0,  0,   //black
255,     255,  255,  255 }; //white

DEFINE_GRADIENT_PALETTE( black_gp ) {
  0,     0,  0,  0,   //black
255,     0,  0,  0 }; //black

void handleRoot() {
    digitalWrite ( led, 1 );
    String out = "<html><head><title>Thanks Plants</title></head>";
    out += "<body style='background-color:gray'><center>";
    out += "<span style='display:block; width:100%; font-size:2em; font-family:Verdana; text-align:center'>Thanks Plants rings lighting</span><br/>";

    out += "<a href='breathe'><span style='display:block; background-color:orange; width:100%; height:3em;'>Breathe</span></a><br/>";
    out += "<a href='awake'><span style='display:block; background-color:orange; width:100%; height:3em;'>Awake</span></a><br/>";
    out += "<a href='chimes'><span style='display:block; background-color:orange; width:100%; height:3em;'>Chimes</span></a><br/>";
    out += "<a href='off'><span style='display:block; background-color:black; width:100%; height:3em;'>Off</span></a><br/>";
    
    out += "<a href='brighten'><span style='display:block; background-color:white; width:100%; height:3em;'>Brighter</span></a><br/>";
    out += "<a href='dim'><span style='display:block; background-color:black; foreground-color:white; width:100%; height:3em;'>Dimmer</span></a><br/>";
    out += "<a href='white'><span style='display:block; background-color:white; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='green'><span style='display:block; background-color:green; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='yellow'><span style='display:block; background-color:yellow; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='orange'><span style='display:block; background-color:orange; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='red'><span style='display:block; background-color:red; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='pink'><span style='display:block; background-color:pink; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='blue'><span style='display:block; background-color:blue; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='black'><span style='display:block; background-color:black; width:100%; height:3em;'></span></a><br/>";
    out += "<a href='sinelon'><span style='display:block; background-color:white; width:100%; height:3em;'>Transition: sinelon</span></a><br/>";
    out += "<a href='bpm'><span style='display:block; background-color:white; width:100%; height:3em;'>Transition: bpm</span></a><br/>";
    out += "<a href='random'><span style='display:block; background-color:white; width:100%; height:3em;'>Transition: random</span></a><br/>";
    out += "<a href='gradient'><span style='display:block; background-color:white; width:100%; height:3em;'>Transition: gradient</span></a><br/>";
    out += "</center></body>";
    out += "</html>";
    server.send ( 200, "text/html", out );
    digitalWrite ( led, 0 );
}

void handleNotFound() {
    digitalWrite ( led, 1 );
    String message = "File Not Found\n\n";
    message += "URI: ";
    message += server.uri();
    message += "\nMethod: ";
    message += ( server.method() == HTTP_GET ) ? "GET" : "POST";
    message += "\nArguments: ";
    message += server.args();
    message += "\n";
    for ( uint8_t i = 0; i < server.args(); i++ ) {
        message += " " + server.argName ( i ) + ": " + server.arg ( i ) + "\n";
    }
    server.send ( 404, "text/plain", message );
    digitalWrite ( led, 0 );
}

void t_sinelon()
{
  // a colored dot sweeping back and forth, with fading trails
  fadeToBlackBy( leds, NUM_LEDS, 2);
  int pos = beatsin16(13,0,NUM_LEDS);
  //leds[pos] += CHSV( idx, 255, 192);
  leds[pos] = ColorFromPalette(palette, idx, 255);
}


void t_bpm()
{
  // colored stripes pulsing at a defined Beats-Per-Minute (BPM)
  uint8_t BeatsPerMinute = 20;
  uint8_t beat = beatsin8( BeatsPerMinute, 32, 255);
  for( int i = 0; i < NUM_LEDS; i++) { //9948
    leds[i] = ColorFromPalette(palette, idx+(i*2), beat-idx+(i*10));
  }
}

void t_random() 
{
  // random colored speckles that blink in and fade smoothly
  fadeToBlackBy( leds, NUM_LEDS, 10);
  int pos = random16(NUM_LEDS);
  //leds[pos] += CHSV( idx + random8(64), 200, 255);
  leds[pos] = ColorFromPalette(palette, idx + random8(64), 255);
}

void t_gradient()
{
    for( int i = 0; i < NUM_LEDS; i++) {
      leds[i] = ColorFromPalette( palette, idx, brightness, LINEARBLEND);
//      colorIndex += 1;
    }
}


void setup ( void ) {
    pinMode ( led, OUTPUT );
    digitalWrite ( led, 0 );

    delay(3000); // 3 second delay for recovery
  
    // tell FastLED about the LED strip configuration
    FastLED.addLeds<LED_TYPE,DATA_PIN,COLOR_ORDER>(leds, NUM_LEDS).setCorrection(TypicalLEDStrip);

    // set master brightness control
    FastLED.setBrightness(brightness);

    testLEDs();
    setColor(6);
 
    Serial.begin ( 115200 );
    // config static IP
    IPAddress ip(192, 168, 0, IP_ADDRESS); // set desired IP Address
    IPAddress subnet(255, 255, 255, 0); // set subnet mask 
    IPAddress gateway(192, 168, 0, 1); // set gateway 
    IPAddress dns(8,8,8,8);
    //WiFi.config(ip, dns, gateway, subnet);
    WiFi.config(ip, gateway, subnet, dns);
    Serial.print(F("Setting static ip to : "));
    Serial.println(ip);
    WiFi.begin ( ssid, password );
    Serial.println ( "" );
    // Wait for connection
    while ( WiFi.status() != WL_CONNECTED ) {
        delay ( 500 );
        Serial.print ( "." );
    }
    
    Serial.println ( "" );
    Serial.print ( "Connected to " );
    Serial.println ( ssid );
    Serial.print ( "IP address: " );
    Serial.println ( WiFi.localIP() );
    if ( mdns.begin ( "esp8266", WiFi.localIP() ) ) {
        Serial.println ( "MDNS responder started" );
    }
    
    server.on ( "/", []() {handleRoot();} );
    
    server.on ( "/breathe", []() {setColor(6); brightness=150 ;transition=3; handleRoot();} );
    server.on ( "/awake", []() {setColor(6); brightness=250; transition=2; handleRoot();} );
    server.on ( "/chimes", []() {setColor(6); brightness=250; transition=4; handleRoot();} );
    server.on ( "/off", []() {setColor(0); handleRoot();} );
        
    server.on ( "/white", []() {setColor(1); handleRoot();} );
    server.on ( "/red", []() {setColor(2); handleRoot();} );
    server.on ( "/green", []() {setColor(3); handleRoot();} );
    server.on ( "/blue", []() {setColor(4); handleRoot();} );
    server.on ( "/yellow", []() {setColor(5); handleRoot();} );
    server.on ( "/orange", []() {setColor(6); handleRoot();} );
    server.on ( "/pink", []() {setColor(7); handleRoot();} );
    server.on ( "/black", []() {setColor(0); handleRoot();} );
    server.on ( "/brighten", []() {brighten(); handleRoot();} );
    server.on ( "/dim", []() {dim(); handleRoot();} );
    server.on ( "/sinelon", []() {transition=1; handleRoot();} );
    server.on ( "/bpm", []() {transition=2; handleRoot();} );
    server.on ( "/gradient", []() {transition=3; handleRoot();} );
    server.on ( "/random", []() {transition=4; handleRoot();} );
    
    server.onNotFound ( handleNotFound );
    server.begin();
    Serial.println ( "HTTP server started" );
}

void loop ( void ) {
    mdns.update();
    server.handleClient();
     // run transition
    if (transition==1) t_sinelon();
    else if (transition==2) t_bpm();
    else if (transition==3) t_gradient();
    else if (transition==4) t_random();
    // reset if reset time has passed
    //if (millis() > reset_time) {
    //  ESP.restart();
    //}
    // send the 'leds' array out to the actual LED strip
    FastLED.show();  
    // insert a delay to keep the framerate modest
    FastLED.delay(1000/FRAMES_PER_SECOND); 
    // do some periodic updates
    EVERY_N_MILLISECONDS( 20 ) { idx++; } // slowly cycle the index variable
    //EVERY_N_MILLISECONDS(5000) { Serial.println(millis()); }
}

void setColor(int color) {
  int i;
  Serial.println(color);
  CRGB c;
  switch (color) {
    case 1:
      c = CRGB::White;
      palette = white_gp;
      break;
    case 2:
      c = CRGB::Red;
      palette = red_gp;
      break;
    case 3:
      c = CRGB::Green;
      palette = green_gp;
      break;
    case 4:
      c = CRGB::Blue;
      palette = blue_gp;
      break;
    case 5:
      c = CRGB::Yellow;
      palette = yellow_gp;
      break;
    case 6:
      c = CRGB::Orange;
      palette = orange_gp;
      break;
    case 7:
      c = CRGB::Pink;
      palette = pink_gp;
      break;
    case 100:
      c = CRGB::White;
      palette = aiml_gp;
      break;
    case 0:
      c = CRGB::Black;
      palette = black_gp;
      break;
  }
    delay(DELAY);
}

void testLEDs(){
  int i;
  Serial.println("Testing LEDs");
  for(int i = 0; i < NUM_LEDS; i++) {
    // set our current dot to red
    Serial.println("Red");
    leds[i] = CRGB::Red;
    FastLED.show();
    delay(DELAY);
  }
  for(int i = 0; i < NUM_LEDS; i++) {
    // set our current dot to green
    Serial.println("Green");
    leds[i] = CRGB::Green;
    FastLED.show();
    delay(DELAY);
  }
  for(int i = 0; i < NUM_LEDS; i++) {
    // set our current dot to blue
    Serial.println("Blue");
    leds[i] = CRGB::Blue;
    FastLED.show();
    delay(DELAY);
  }
}

void setBrightness(int newBrightness) 
{
  brightness = newBrightness;
  FastLED.setBrightness(brightness);
  Serial.print("Brightness: ");
  Serial.println(brightness);
}

void brighten()
{
  brightness+=20;
  if (brightness>250) brightness=250;
  FastLED.setBrightness(brightness);
  Serial.print("Brightness: ");
  Serial.println(brightness);
}

void dim()
{
  brightness-=20;
  if (brightness<0) brightness=0;
  FastLED.setBrightness(brightness);
  Serial.print("Brightness: ");
  Serial.println(brightness);
}

