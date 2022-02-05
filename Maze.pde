/**
 **********************************************************************************************************************
 * @file       Maze.pde
 * @author     Anuradha Herath (overidden from Hello_Wall skecth by Steve and Colin)
 * @version    V1.0
 * @date       03-February-2022
 * @brief      A haptic maze programmed with physics for haply 
 **********************************************************************************************************************
*/

/* library imports *****************************************************************************************************/ 
import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;

/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);


/* device block definitions ********************************************************************************************/
Board             haplyBoard;
Device            haplyDevice;
Mechanisms        pantograph;

byte              deviceID                         = 5;
int               CW                                  = 0;
int               CCW                                 = 1;
boolean           renderingForce                     = false;

/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;

/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerMeter                      = 4000.0;
float             radsPerDegree                       = 0.01745;

/* pantagraph link parameters in meters */
float             l                                   = 0.07;
float             L                                   = 0.09;


/* end effector radius in meters */
float             radiusEE                                 = 0.004;

/* virtual wall parameter  */
float             kWall                               = 650;
PVector           forceWall                           = new PVector(0, 0);
PVector           penWall                             = new PVector(0, 0);
PVector           posWall                             = new PVector(0.02, 0.10);    // max y: 0.13
PVector           posWall2                            = new PVector(0.08, 0.10);

private ArrayList<Wall> verticalMWalls;
private ArrayList<Wall> horizontalMWalls;


// total length of the canvas : 0.2 (-0.1 to 0.1)
// Wall coordinate information
float [][] verticalW = new float[][]{
                                      {-.08, .03, .07}, {-.064, .044, .014}, {-.048, .058, .014}, {-.032, .03, .028}, {-.032, .072, .014}, {-.016, .058, .014},
                                      {-.016, .086, .014}, {0, .044, .014}, {0, .072, .014}, {.016, .03, .014}, {.016, .058, .014}, {.016, .086, .014},
                                      {.032, .044, .014}, {.032, .072, .014}, {.048, .044, .028}, {.064, .058, .014}, {.08, .03, .07}
                                    };
float [][] horizontalW = new float[][]{
                                      {-.064, .03, .144}, 
                                      {-.064, .044, .016}, {-.016, .044, .016}, {.032, .044, .032}, 
                                      {-.064, .058, .048}, {0, .058, .016}, {.064, .058, .016},
                                      {-.08, .072, .016}, {-.032, .072, .016}, {.016, .072, .032}, 
                                      {-.064, .086, .032}, {0, .086, .032}, {.048, .086, .032},
                                      {-.08, .1, .144}
                                    };

/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           forceEE                             = new PVector(0, 0);

/* device graphical position */
PVector           deviceOrigin                        = new PVector(0, 0);
PVector  translateTemp = new PVector(0,0);

/* World boundaries reference */
final int         worldPixelWidth                     = 1000;
final int         worldPixelHeight                    = 650;


/* graphical elements */
PShape pGraph, joint, endEffector;
PShape wall, wall2;

/*********************************************************************************************/



/* setup section *******************************************************************************************************/
void setup() {
  /* put setup code here, run once: */

  /* screen size definition */
  size(1000, 650);

  /* device setup */
  haplyBoard = new Board(this, Serial.list()[0], 0);
  haplyDevice = new Device(deviceID, haplyBoard);
  pantograph = new Pantograph();

  haplyDevice.set_mechanism(pantograph);

  haplyDevice.add_actuator(1, CCW, 2);
  haplyDevice.add_actuator(2, CW, 1);

  haplyDevice.add_encoder(1, CCW, 241, 10752, 2);
  haplyDevice.add_encoder(2, CW, -61, 10752, 1);

  haplyDevice.device_set_parameters();


  /* visual elements setup */
  deviceOrigin.add(worldPixelWidth/2, 0);

  /* create pantagraph graphics */
  init_pantagraph_draw();
  
  // Initialize Walls
  verticalMWalls = new ArrayList();
  horizontalMWalls = new ArrayList();
  

  /* create wall graphics */
  //verticalMWalls.add(new Wall(new PVector(-0.8, 0.03), 0.07));
  for(int i = 0; i< verticalW.length; i++){
    verticalMWalls.add(new Wall(new PVector(verticalW[i][0], verticalW[i][1]), create_wall(verticalW[i][0], verticalW[i][1], verticalW[i][0], verticalW[i][1] + verticalW[i][2]),  verticalW[i][2]));
  }
  for(int i = 0; i< horizontalW.length; i++){
    horizontalMWalls.add(new Wall(new PVector(horizontalW[i][0], horizontalW[i][1]), create_wall(horizontalW[i][0], horizontalW[i][1], horizontalW[i][0] + horizontalW[i][2] , horizontalW[i][1] ),  horizontalW[i][2]));
  }
  
  //wall = create_wall( posWall.x - 0.1, posWall.y+radiusEE, posWall.x+0.06, posWall.y+radiusEE);
  //wall.setStroke(color(0));
  //wall2 = create_wall(posWall2.x, posWall2.y+radiusEE, posWall2.x, radiusEE + 0.03 );
  //wall2.setStroke(color(100));


  /* setup framerate speed */
  frameRate(baseFrameRate);


  /* setup simulation thread to run at 1kHz */
  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 1, MILLISECONDS);
}
/****************************************************************************************************/



/* draw section ********************************************************************************************************/
void draw() {
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  if (renderingForce == false) {
    background(255);
    update_animation(angles.x*radsPerDegree, angles.y*radsPerDegree, posEE.x, posEE.y);
  }
}
/*****************************************************************************************************/



/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable {

  public void run() {
    /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */

    renderingForce = true;

    if (haplyBoard.data_available()) {
      /* GET END-EFFECTOR STATE (TASK SPACE) */
      haplyDevice.device_read_data();

      angles.set(haplyDevice.get_device_angles());
      posEE.set(haplyDevice.get_device_position(angles.array()));
      posEE.set(device_to_graphics(posEE));

      //println(posEE.y);


      /* haptic wall force calculation */
      forceWall.set(0, 0);

      //penWall.set(0, (posWall.y - (posEE.y + radiusEE)));

      //if (penWall.y < 0) {
      //  forceWall = forceWall.add(penWall.mult(-kWall));
      //}
      
      //penWall.set((posWall2.x - (posEE.x + radiusEE)), 0);
      ////println(""+ penWall.x);
      //if(penWall.x < 0 ){
       
      //  forceWall = forceWall.add(penWall.mult(-kWall));
      //}
      
      float tempX = posEE.x;
      float tempY = posEE.y;
      
      for(Wall hWall: horizontalMWalls){
        if(Math.abs(tempY - hWall.startPos.y) <= radiusEE){
            if(hWall.startPos.x <= tempX && hWall.startPos.x + hWall.wlength > tempX ){
              penWall.set(0,(hWall.startPos.y - (tempY + radiusEE)));
              if(tempY > hWall.startPos.y){
                forceWall = forceWall.add(penWall.mult(kWall));
              }else{
                forceWall = forceWall.add(penWall.mult(-kWall));
              }
              
            }
        }
      }
      
      for(Wall vWall: verticalMWalls){
        if(Math.abs(tempX - vWall.startPos.x) <= radiusEE){
            if(vWall.startPos.y <= tempY && vWall.startPos.y + vWall.wlength > tempY ){
              penWall.set((vWall.startPos.x - (tempX + radiusEE)), 0);
              if(tempX > vWall.startPos.x){
                forceWall = forceWall.add(penWall.mult(kWall));
              }else {
                forceWall = forceWall.add(penWall.mult(-kWall));
              }
            }
        }
      }
      

      forceEE = (forceWall.copy()).mult(-1);
      forceEE.set(graphics_to_device(forceEE));
      /* end haptic wall force calculation */
    }


    torques.set(haplyDevice.set_device_torques(forceEE.array()));
    haplyDevice.device_write_torques();


    renderingForce = false;
  }
}
/***********************************************************************************************/


/* helper functions section, place helper functions here ***************************************************************/
void init_pantagraph_draw() {
  //float lAni = pixelsPerMeter * l;
  //float LAni = pixelsPerMeter * L;
  float radiusEEAni = pixelsPerMeter * radiusEE;

  //pGraph = createShape();
  //pGraph.beginShape();
  //pGraph.fill(255);
  //pGraph.stroke(0);
  //pGraph.strokeWeight(2);

  //pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
  //pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
  //pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
  //pGraph.vertex(deviceOrigin.x, deviceOrigin.y);
  //pGraph.endShape(CLOSE);

  //joint = createShape(ELLIPSE, deviceOrigin.x, deviceOrigin.y, radiusEEAni, radiusEEAni);
  //joint.setStroke(color(0));

  endEffector = createShape(ELLIPSE, deviceOrigin.x, deviceOrigin.y, radiusEEAni, radiusEEAni);
  endEffector.setStroke(color(0));
  endEffector.setFill(color(50));
  strokeWeight(5);
}


PShape create_wall(float x1, float y1, float x2, float y2) {
  x1 = pixelsPerMeter * x1;
  y1 = pixelsPerMeter * y1;
  x2 = pixelsPerMeter * x2;
  y2 = pixelsPerMeter * y2;
  
  PShape temp = createShape(LINE, deviceOrigin.x + x1, deviceOrigin.y + y1, deviceOrigin.x + x2, deviceOrigin.y+y2);
  temp.setStroke(color(0));
  return temp;
}

PShape create_wall(float xbegin, float ybegin){
  return null;
};


void update_animation(float th1, float th2, float xE, float yE) {
  background(255);

  //float lAni = pixelsPerMeter * l;
  //float LAni = pixelsPerMeter * L;
  //println(xE + ", " + yE);
  xE = pixelsPerMeter * xE;
  yE = pixelsPerMeter * yE;
  th1 = 3.14 - th1;
  th2 = 3.14 - th2;

  //pGraph.setVertex(1, deviceOrigin.x + lAni*cos(th1), deviceOrigin.y + lAni*sin(th1));
  //pGraph.setVertex(3, deviceOrigin.x + lAni*cos(th2), deviceOrigin.y + lAni*sin(th2));
  //pGraph.setVertex(2, deviceOrigin.x + xE, deviceOrigin.y + yE);

  //shape(pGraph);
  //shape(joint);
  //shape(wall);
  //shape(wall2);
  
  for(Wall vWall: verticalMWalls){
    shape(vWall.wallShape);
  }
  for(Wall hWall: horizontalMWalls){
    shape(hWall.wallShape);
  }
  
  //wall = create_wall(posWall.x-0.2, posWall.y-radiusEE/2, posWall.x+0.2, posWall.y-radiusEE/2);
  //wall.setStroke(color(60));
  //translateLocation(posEE);
  translate(xE, yE);
  //translate(translateTemp.x, translateTemp.y);
  shape(endEffector);
}

//void translateLocation(PVector inputLoc){
//  float x = (((inputLoc.x) * (worldPixelWidth - 100))/ 0.18);
//  float y = (((inputLoc.y - 0.02) * (worldPixelHeight - 50))/ 0.08) + 50;
//  if(x < 100) x = 100;
//  translateTemp.set(x, y);
//}

PVector device_to_graphics(PVector deviceFrame) {
  return deviceFrame.set(-deviceFrame.x, deviceFrame.y);
}


PVector graphics_to_device(PVector graphicsFrame) {
  return graphicsFrame.set(-graphicsFrame.x, graphicsFrame.y);
}

class Wall{
  PVector startPos;
  float wlength;
  PShape wallShape;
  
  public Wall(PVector sp, PShape ws, float len){
    startPos = sp;
    wallShape = ws;
    wlength = len;
  }
}

/*****************************************************************************************/
