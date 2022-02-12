/**
 **********************************************************************************************************************
 * @file       Sketch_Word_Communication.pde
 * @author     Anuradha Herath  (based on Maze by Elie Hymowitz, Steve Ding, Colin Gallacher)
 * @version    V1.0.0
 * @date       10-February-2021
 * @brief      A Sketch to convey emotions through the Haply
 **********************************************************************************************************************
 * @attention
 *
 *
 **********************************************************************************************************************
 */



/* library imports *****************************************************************************************************/ 
import processing.serial.*;
import static java.util.concurrent.TimeUnit.*;
import java.util.concurrent.*;
import java.lang.Math;
/* end library imports *************************************************************************************************/  



/* scheduler definition ************************************************************************************************/ 
private final ScheduledExecutorService scheduler      = Executors.newScheduledThreadPool(1);
/* end scheduler definition ********************************************************************************************/ 



/* device block definitions ********************************************************************************************/
Board             haplyBoard;
Device            widgetOne;
Mechanisms        pantograph;

byte              widgetOneID                         = 5;
int               CW                                  = 0;
int               CCW                                 = 1;
boolean           renderingForce                     = false;
/* end device block definition *****************************************************************************************/



/* framerate definition ************************************************************************************************/
long              baseFrameRate                       = 120;
/* end framerate definition ********************************************************************************************/ 



/* elements definition *************************************************************************************************/

/* Screen and world setup parameters */
float             pixelsPerCentimeter                 = 30.0;

/* generic data for a 2DOF device */
/* joint space */
PVector           angles                              = new PVector(0, 0);
PVector           torques                             = new PVector(0, 0);

/* task space */
PVector           posEE                               = new PVector(0, 0);
PVector           fEE                                 = new PVector(0, 0); 

/* World boundaries */
FWorld            world;
float             worldWidth                          = 32.0;  
float             worldHeight                         = 32.0; 

float             edgeTopLeftX                        = 0.0; 
float             edgeTopLeftY                        = 0.0; 
float             edgeBottomRightX                    = worldWidth; 
float             edgeBottomRightY                    = worldHeight;

float             gravityAcceleration                 = 980; //cm/s2
/* Initialization of virtual tool */
HVirtualCoupling  sensor;

/* define game start */
boolean           gameStart                           = false;

/* define boundaries */
FPoly firstBoundary;
FPoly secondBoundary;
FBox thirdBoundary;

float radius_1 = worldWidth/2;
float radius_2 = worldWidth/4;

/* define force and damping */
float dampingForce = 0;
float virtualCouplingX = 0;
float virtualCouplingY = 0;
float dampingScale = 10000;

/* text font */
PFont             font;

/* end elements definition *********************************************************************************************/  



/* setup section *******************************************************************************************************/
void setup(){
  /* put setup code here, run once: */
  
  /* screen size definition */
  size(980, 850);
  
  /* set font type and size */
  font = createFont("Arial", 16, true);

  
  /* device setup */
  
  /**  
   * The board declaration needs to be changed depending on which USB serial port the Haply board is connected.
   * In the base example, a connection is setup to the first detected serial device, this parameter can be changed
   * to explicitly state the serial port will look like the following for different OS:
   *
   *      windows:      haplyBoard = new Board(this, "COM10", 0);
   *      linux:        haplyBoard = new Board(this, "/dev/ttyUSB0", 0);
   *      mac:          haplyBoard = new Board(this, "/dev/cu.usbmodem1411", 0);
   */
  haplyBoard = new Board(this, Serial.list()[0], 0);
  widgetOne = new Device(widgetOneID, haplyBoard);
  pantograph = new Pantograph();
  
  widgetOne.set_mechanism(pantograph);

  widgetOne.add_actuator(1, CCW, 2);
  widgetOne.add_actuator(2, CW, 1);
 
  widgetOne.add_encoder(1, CCW, 241, 10752, 2);
  widgetOne.add_encoder(2, CW, -61, 10752, 1);
  
  
  widgetOne.device_set_parameters();
  
  
  /* 2D physics scaling and world creation */
  hAPI_Fisica.init(this); 
  hAPI_Fisica.setScale(pixelsPerCentimeter); 
  world = new FWorld();

  /* Set Boundaries */
  firstBoundary = new FPoly();
  secondBoundary = new FPoly();
  thirdBoundary = new FBox(worldWidth, 3*worldHeight/4 + 1);

  firstBoundary.vertex(worldWidth/2, 1);
  secondBoundary.vertex(worldWidth/2, 1);

  for(float i = 0; i < Math.PI; i += 0.01){
    firstBoundary.vertex((float) (0.4 + (worldWidth/2) - radius_2 * Math.cos(i)), (float) (radius_2 * Math.sin(i)) + 1);
    secondBoundary.vertex((float) (0.4 + (worldWidth/2) - radius_1 * Math.cos(i)), (float) (radius_1 * Math.sin(i)) + 1);
  }

  firstBoundary.vertex(worldWidth/2, 1);
  firstBoundary.setStaticBody(true);
  firstBoundary.setDensity(500);
  firstBoundary.setFill(5, 123, 166);

  secondBoundary.vertex(worldWidth/2, 1);
  secondBoundary.setStaticBody(true);
  secondBoundary.setDensity(1000);
  secondBoundary.setFill(250, 250, 100);

  thirdBoundary.setPosition(0.4 + edgeTopLeftX + worldWidth/2, worldHeight/2 - 2.5 );
  thirdBoundary.setStaticBody(true);
  thirdBoundary.setFill(150, 0, 0, 230);


  world.add(thirdBoundary);
  world.add(secondBoundary);
  world.add(firstBoundary);
  
  
  /* Setup the Virtual Coupling Contact Rendering Technique */
  sensor = new HVirtualCoupling((0.5)); 
  sensor.h_avatar.setDensity(4); 
  sensor.h_avatar.setFill(255,0,0); 
  sensor.h_avatar.setSensor(true);

  sensor.init(world, edgeTopLeftX+worldWidth/2, edgeTopLeftY+3); 
  
  /* World conditions setup */
  world.setGravity((0.0), gravityAcceleration); //1000 cm/(s^2)
 
  world.draw();
  
  
  /* setup framerate speed */
  frameRate(baseFrameRate);
  
  
  /* setup simulation thread to run at 1kHz */
  SimulationThread st = new SimulationThread();
  scheduler.scheduleAtFixedRate(st, 1, 1, MILLISECONDS);
}
/* end setup section ***************************************************************************************************/



/* draw section ********************************************************************************************************/
void draw(){
  /* put graphical code here, runs repeatedly at defined framerate in setup, else default at 60fps: */
  if(renderingForce == false){
    background(255);
    
    world.draw();
  }
}
/* end draw section ****************************************************************************************************/



/* simulation section **************************************************************************************************/
class SimulationThread implements Runnable{
  
  public void run(){
    /* put haptic simulation code here, runs repeatedly at 1kHz as defined in setup */
    
    renderingForce = true;
    
    if(haplyBoard.data_available()){
      /* GET END-EFFECTOR STATE (TASK SPACE) */
      widgetOne.device_read_data();
    
      angles.set(widgetOne.get_device_angles()); 
      posEE.set(widgetOne.get_device_position(angles.array()));
      posEE.set(posEE.copy().mult(200));  
    }
    
    sensor.setToolPosition(edgeTopLeftX+worldWidth/2-(posEE).x, edgeTopLeftY+(posEE).y-4); 
    sensor.updateCouplingForce();

    virtualCouplingX = sensor.getVirtualCouplingForceX();
    virtualCouplingY = sensor.getVirtualCouplingForceY();   

    // ---------------Setting up the Vocabulary throught the created objects--------------

    if(sensor.h_avatar.isTouchingBody(firstBoundary)){
      dampingForce = 900;
      virtualCouplingX = -virtualCouplingX;
      dampingScale = 100000;

    }else if(!sensor.h_avatar.isTouchingBody(firstBoundary) && sensor.h_avatar.isTouchingBody(secondBoundary)){
      dampingForce = 900;
      dampingScale = 10000;
    }else if(!sensor.h_avatar.isTouchingBody(secondBoundary) && sensor.h_avatar.isTouchingBody(thirdBoundary)){
      dampingForce = 250;
      virtualCouplingX = -virtualCouplingX;
      virtualCouplingY = -virtualCouplingY;
    }else{
      dampingForce = 0;
      dampingScale = 100000;
    }

    // ------------------ End set-up --------------------------------------------------

    sensor.h_avatar.setDamping(dampingForce);
    fEE.set(virtualCouplingX, virtualCouplingY);
    fEE.div(dampingScale);                        // to reduce the force on the end effector

    torques.set(widgetOne.set_device_torques(fEE.array()));
    widgetOne.device_write_torques();
  
    world.step(1.0f/1000.0f);
  
    renderingForce = false;
  }
}
/* end simulation section **********************************************************************************************/



/* helper functions section, place helper functions here ***************************************************************/


/* end helper functions section ****************************************************************************************/
