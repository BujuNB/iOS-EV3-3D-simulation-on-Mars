//
//  ViewController.m
//  EV3Car
//
//  Created by BlowBMakers on 3/11/16.
//  Copyright (c) 2016 BlowBMakers. All rights reserved.
//

#import "ViewController.h"
#import <ExternalAccessory/ExternalAccessory.h>
#import "EADSessionController.h"
#import "EV3DirectCommander.h"
//#import <CoreMotion/CoreMotion.h>
//#import "SRMotionDetector.h"
//#import <math.h>

#import "AAPLGameView.h"
#import "AAPLOverlayScene.h"

@interface ViewController ()
{
    BOOL isConnected;
    
    //game scene
    //some node references for manipulation
    SCNNode *_spotLightNode;
    SCNNode *_cameraNode;          //the node that owns the camera
    SCNNode *_vehicleNode;
    SCNPhysicsVehicle *_vehicle;
    SCNParticleSystem *_reactor;
    
    //accelerometer
    //CMMotionManager *_motionManager;
    UIAccelerationValue	_accelerometer[3];
    CGFloat _orientation;
    
    //reactor's particle birth rate
    CGFloat _reactorDefaultBirthRate;
    
    // steering factor
    CGFloat _vehicleSteering;
    int _engineForce;
    CGFloat _breakForce;
    
    NSTimeInterval timecount;
    
    BOOL didcontact;
}
@property (nonatomic,strong) EADSessionController *sessionController;
@property (nonatomic,strong) EAAccessory *ev3Device;
@property (nonatomic,strong) NSTimer *timer;
//@property (nonatomic,strong) CMMotionManager *motionManager;

@end

#define MAX_SPEED 250

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    isConnected = NO;
    
    timecount = 0;
    
    didcontact = NO;

    CGRect rc = self.view.frame;
    
    self.view = [[AAPLGameView alloc] initWithFrame:rc];
    
    self.view.backgroundColor = [UIColor whiteColor];
    
    //game scene
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    
    SCNView *scnView = (SCNView *) self.view;
    
    //set the background to back
    scnView.backgroundColor = [SKColor blackColor];
    
    //setup the scene
    SCNScene *scene = [self setupScene];
    
    //present it
    scnView.scene = scene;
    
    //tweak physics
    scnView.scene.physicsWorld.speed = 4.0;
    
    //setup overlays
    scnView.overlaySKScene = [[AAPLOverlayScene alloc] initWithSize:scnView.bounds.size];
    
    //setup accelerometer
    //[self setupAccelerometer];
    
    //initial point of view
    scnView.pointOfView = _cameraNode;
    
    //plug game logic
    scnView.delegate = self;
    
    
    JSAnalogueStick *stick = [[JSAnalogueStick alloc] initWithFrame:CGRectMake(20, 200, 100, 100)];
    stick.delegate = self;
    [self.view addSubview:stick];
    
    //[[SRMotionDetector sharedInstance] startUpdate];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopRot) name:@"stopRot" object:nil];
    
}

- (void)stopRot{
    NSData *data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:0 port:EV3OutputPortC power:0];
    
    [[EADSessionController sharedController] writeData:data];
}

- (IBAction)calibration:(id)sender
{
    //[[SRMotionDetector sharedInstance] reset];
}

- (IBAction)connectEv3:(UISwitch *)sender
{
    if (sender.isOn && !isConnected) {
        NSLog(@"connect EV3");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidConnect:) name:EAAccessoryDidConnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(accessoryDidDisconnect:) name:EAAccessoryDidDisconnectNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionDataReceived:) name:EADSessionDataReceivedNotification object:nil];
        [[EAAccessoryManager sharedAccessoryManager] registerForLocalNotifications];
        self.sessionController = [EADSessionController sharedController];
        NSMutableArray *accessoryList = [[NSMutableArray alloc] initWithArray:[[EAAccessoryManager sharedAccessoryManager] connectedAccessories]];
        NSLog(@"accessory list:%@",accessoryList);
        if(accessoryList != nil){
            [self.sessionController setupControllerForAccessory:[accessoryList firstObject]
                                             withProtocolString:@"COM.LEGO.MINDSTORMS.EV3"];
            isConnected = [self.sessionController openSession];
            if (isConnected) {
                NSLog(@"ev3 on");
            }
            else {
                [sender setOn:NO animated:YES];
            }
        }
        
    } else {
        
        NSLog(@"ev3 off");
        
        if (isConnected) {
            NSData *data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:0 port:EV3OutputPortD power:0];
            [[EADSessionController sharedController] writeData:data];
            [self.timer invalidate];
            
            

        }
        
        [self.sessionController closeSession];
        isConnected = NO;
    }

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)accessoryDidConnect:(NSNotification *)notification {
    NSLog(@"accessory Did Connect");
    
}

- (void)accessoryDidDisconnect:(NSNotification *)notification {
    NSLog(@"accessory Did Disconnect");
    [self.timer invalidate];
}

- (void)sessionDataReceived:(NSNotification *)notification
{
}

- (IBAction)stopEV3:(id)sender
{
    if (isConnected) {
        NSData *data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:0 port:EV3OutputPortD power:0];
        [[EADSessionController sharedController] writeData:data];
        [self.timer invalidate];
    }
}

-(void)analogueStickDidChangeValue:(JSAnalogueStick *)analogueStick
{
    
    
    NSTimeInterval cur = [[NSDate date] timeIntervalSince1970];
    if (cur - timecount > 0.5) {
        timecount = cur;
    }
    else {
        //timecount++;
        return;
    }
    //if (timecount > 100000)
    if (analogueStick.yValue < 0)
    {
        NSLog(@"下");

        if (!didcontact) {
            float angle = atanf(fabs(analogueStick.xValue)/(fabs(analogueStick.yValue)+0.00001));
            
            NSData *data;
            if (analogueStick.xValue < 0) {
                
                _vehicleSteering = 0.4*angle/1.57;
                
                data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:50 port:EV3OutputPortC power:50-angle/1.57*50];
                
            }
            else {
                
                _vehicleSteering = -0.4*angle/1.57;
                
                data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:50-angle/1.57*50 port:EV3OutputPortC power:50];
            }
            
            [[EADSessionController sharedController] writeData:data];
        }
        
        
        _engineForce = -100;

        
    }
    else if (analogueStick.yValue > 0)
    {
        NSLog(@"上");
        float angle = atanf(fabs(analogueStick.xValue)/(fabs(analogueStick.yValue)+0.00001));
        
        if (!didcontact) {
            
            NSData *data;
            if (analogueStick.xValue < 0) {
            
                _vehicleSteering = 0.4*angle/1.57;
            
                data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:-50 port:EV3OutputPortC power:-50+angle/1.57*50];
            
            }
            else {
            
                _vehicleSteering = -0.4*angle/1.57;
                
                data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:-50+angle/1.57*50 port:EV3OutputPortC power:-50];
            }
        
            [[EADSessionController sharedController] writeData:data];
        }
        
        _engineForce = 100;

    }
    
    NSLog(@"%f>>>>>%f>>>>>>>>%f>>>>>>%f",analogueStick.xValue,analogueStick.yValue,analogueStick.center.x,analogueStick.center.y);
}

-(void)analogueStickTouchEnd:(JSAnalogueStick *)stick
{
    
    NSLog(@"analogueStickTouchEnd");
    
    NSData *data = [EV3DirectCommander turnMotorsAtPort:EV3OutputPortB power:0 port:EV3OutputPortC power:0];
    
    [[EADSessionController sharedController] writeData:data];
    
    _engineForce = 0;
    
    _breakForce = 100;
    
    _vehicleSteering = 0;
}

- (void)setupEnvironment:(SCNScene *)scene
{
    // add an ambient light
    SCNNode *ambientLight = [SCNNode node];
    ambientLight.light = [SCNLight light];
    ambientLight.light.type = SCNLightTypeAmbient;
    ambientLight.light.color = [UIColor colorWithWhite:0.3 alpha:1.0];
    [[scene rootNode] addChildNode:ambientLight];
    
    //add a key light to the scene
    SCNNode *lightNode = [SCNNode node];
    lightNode.light = [SCNLight light];
    lightNode.light.type = SCNLightTypeSpot;

    
    lightNode.light.color = [UIColor colorWithWhite:0.8 alpha:1.0];
    lightNode.position = SCNVector3Make(0, 80, 30);
    lightNode.rotation = SCNVector4Make(1,0,0,-M_PI/2.8);
    lightNode.light.spotInnerAngle = 0;
    lightNode.light.spotOuterAngle = 50;
    lightNode.light.shadowColor = [SKColor blackColor];
    lightNode.light.zFar = 500;
    lightNode.light.zNear = 50;
    [[scene rootNode] addChildNode:lightNode];
    
    //keep an ivar for later manipulation
    _spotLightNode = lightNode;
    
    //ground
    SCNNode*floor = [SCNNode node];
    floor.geometry = [SCNFloor floor];
    floor.geometry.firstMaterial.diffuse.contents = @"mars_ground.jpg";
    floor.geometry.firstMaterial.diffuse.contentsTransform = SCNMatrix4MakeScale(2, 2, 1); //scale the  texture
    floor.geometry.firstMaterial.locksAmbientWithDiffuse = YES;
    
    SCNPhysicsBody *staticBody = [SCNPhysicsBody staticBody];
    floor.physicsBody = staticBody;
    [[scene rootNode] addChildNode:floor];
    
    scene.physicsWorld.contactDelegate = self;
    
//    SCNScene *terrainScene = [SCNScene sceneNamed:@"terrain"];
//    SCNNode *chassisNode = [terrainScene.rootNode childNodeWithName:@"terrainBody" recursively:NO];
//    chassisNode.position = SCNVector3Make(0, 10, 30);
//    chassisNode.scale = SCNVector3Make(10, 10, 10);
//    SCNPhysicsBody *terrainBody = [SCNPhysicsBody staticBody];
//    chassisNode.physicsBody = terrainBody;
//    [scene.rootNode addChildNode:chassisNode];
    
}

- (SCNNode *)setupVehicle:(SCNScene *)scene
{
    SCNScene *carScene = [SCNScene sceneNamed:@"rc_car"];
    SCNNode *chassisNode = [carScene.rootNode childNodeWithName:@"rccarBody" recursively:NO];
    
    // setup the chassis
    chassisNode.position = SCNVector3Make(0, 10, 30);
    chassisNode.rotation = SCNVector4Make(0, 1, 0, M_PI);
    
    SCNPhysicsBody *body = [SCNPhysicsBody dynamicBody];
    body.allowsResting = NO;
    body.mass = 80;
    body.restitution = 0.1;
    body.friction = 0.5;
    body.rollingFriction = 0;
    body.contactTestBitMask = SCNPhysicsCollisionCategoryStatic;
    
    
    chassisNode.physicsBody = body;
    [scene.rootNode addChildNode:chassisNode];
    
    SCNNode *pipeNode = [chassisNode childNodeWithName:@"pipe" recursively:YES];
    _reactor = [SCNParticleSystem particleSystemNamed:@"reactor" inDirectory:nil];
    _reactorDefaultBirthRate = _reactor.birthRate;
    _reactor.birthRate = 0;
    [pipeNode addParticleSystem:_reactor];
    
    //add wheels
    SCNNode *wheel0Node = [chassisNode childNodeWithName:@"wheelLocator_FL" recursively:YES];
    SCNNode *wheel1Node = [chassisNode childNodeWithName:@"wheelLocator_FR" recursively:YES];
    SCNNode *wheel2Node = [chassisNode childNodeWithName:@"wheelLocator_RL" recursively:YES];
    SCNNode *wheel3Node = [chassisNode childNodeWithName:@"wheelLocator_RR" recursively:YES];
    
    SCNPhysicsVehicleWheel *wheel0 = [SCNPhysicsVehicleWheel wheelWithNode:wheel0Node];
    SCNPhysicsVehicleWheel *wheel1 = [SCNPhysicsVehicleWheel wheelWithNode:wheel1Node];
    SCNPhysicsVehicleWheel *wheel2 = [SCNPhysicsVehicleWheel wheelWithNode:wheel2Node];
    SCNPhysicsVehicleWheel *wheel3 = [SCNPhysicsVehicleWheel wheelWithNode:wheel3Node];
    
    SCNVector3 min, max;
    [wheel0Node getBoundingBoxMin:&min max:&max];
    CGFloat wheelHalfWidth = 0.5 * (max.x - min.x);
    
    wheel0.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel0Node convertPosition:SCNVector3Zero toNode:chassisNode]) + (vector_float3){wheelHalfWidth, 0.0, 0.0});
    wheel1.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel1Node convertPosition:SCNVector3Zero toNode:chassisNode]) - (vector_float3){wheelHalfWidth, 0.0, 0.0});
    wheel2.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel2Node convertPosition:SCNVector3Zero toNode:chassisNode]) + (vector_float3){wheelHalfWidth, 0.0, 0.0});
    wheel3.connectionPosition = SCNVector3FromFloat3(SCNVector3ToFloat3([wheel3Node convertPosition:SCNVector3Zero toNode:chassisNode]) - (vector_float3){wheelHalfWidth, 0.0, 0.0});
    
    // create the physics vehicle
    SCNPhysicsVehicle *vehicle = [SCNPhysicsVehicle vehicleWithChassisBody:chassisNode.physicsBody wheels:@[wheel0, wheel1, wheel2, wheel3]];
    [scene.physicsWorld addBehavior:vehicle];
    
    _vehicle = vehicle;
    
    return chassisNode;
}

- (SCNScene *)setupScene
{
    // create a new scene
    SCNScene *scene = [SCNScene scene];
    
    //global environment
    [self setupEnvironment:scene];
    
    [self addWoodenBlockToScene:scene withImageNamed:@"stone.jpg" atPosition:SCNVector3Make(-10, 5, 10) withScale:SCNVector3Make(10, 10, 10)];
    //[self addWoodenBlockToScene:scene withImageNamed:@"WoodCubeB.jpg" atPosition:SCNVector3Make( -9, 10, 10) withScale:SCNVector3Make(20, 5, 20)];
    [self addWoodenBlockToScene:scene withImageNamed:@"stone.jpg" atPosition:SCNVector3Make(20, 5, -11) withScale:SCNVector3Make(8, 10, 10)];
    [self addWoodenBlockToScene:scene withImageNamed:@"stone.jpg" atPosition:SCNVector3Make(35, 3, -20) withScale:SCNVector3Make(5, 6, 5)];
    [self addWoodenBlockToScene:scene withImageNamed:@"stone2.jpg" atPosition:SCNVector3Make(-35, 3, 50) withScale:SCNVector3Make(5, 6, 5)];
    
    [self addWoodenBlockToScene:scene withImageNamed:@"stone2.jpg" atPosition:SCNVector3Make(-50, 5, 80) withScale:SCNVector3Make(10, 10, 10)];
    [self addWoodenBlockToScene:scene withImageNamed:@"stone2.jpg" atPosition:SCNVector3Make(-60, 5, 100) withScale:SCNVector3Make(10, 10, 10)];
    
    [self addWoodenBlockToScene:scene withImageNamed:@"stone2.jpg" atPosition:SCNVector3Make(-85, 3, 50) withScale:SCNVector3Make(5, 6, 5)];
    
    [self addWoodenBlockToScene:scene withImageNamed:@"stone2.jpg" atPosition:SCNVector3Make(-50, 5, 180) withScale:SCNVector3Make(10, 10, 10)];
    [self addWoodenBlockToScene:scene withImageNamed:@"stone2.jpg" atPosition:SCNVector3Make(-60, 5, 200) withScale:SCNVector3Make(10, 10, 10)];
    
    //setup vehicle
    _vehicleNode = [self setupVehicle:scene];
    
    //create a main camera
    _cameraNode = [[SCNNode alloc] init];
    _cameraNode.camera = [SCNCamera camera];
    _cameraNode.camera.zFar = 500;
    _cameraNode.position = SCNVector3Make(0, 60, 50);
    _cameraNode.rotation  = SCNVector4Make(1, 0, 0, -M_PI_4*0.75);
    [scene.rootNode addChildNode:_cameraNode];
    
    //add a secondary camera to the car
    SCNNode *frontCameraNode = [SCNNode node];
    frontCameraNode.position = SCNVector3Make(0, 3.5, 2.5);
    frontCameraNode.rotation = SCNVector4Make(0, 1, 0, M_PI);
    frontCameraNode.camera = [SCNCamera camera];
    frontCameraNode.camera.xFov = 75;
    frontCameraNode.camera.zFar = 500;
    
    [_vehicleNode addChildNode:frontCameraNode];
    
    return scene;
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

// game logic
- (void)renderer:(id<SCNSceneRenderer>)aRenderer didSimulatePhysicsAtTime:(NSTimeInterval)time
{
    const float cameraDamping = 0.3;
    
    AAPLGameView *scnView = (AAPLGameView*)self.view;
    
    
    //NSArray* controllers = [GCController controllers];
    
    
    //drive: 1 touch = accelerate, 2 touches = backward, 3 touches = brake
//    if (scnView.touchCount == 1) {
//        engineForce = defaultEngineForce;
//        _reactor.birthRate = _reactorDefaultBirthRate;
//    }
//    else if (scnView.touchCount == 2) {
//        engineForce = -defaultEngineForce;
//        _reactor.birthRate = 0;
//    }
//    else if (scnView.touchCount == 3) {
//        brakingForce = 100;
//        _reactor.birthRate = 0;
//    }
//    else {
//        brakingForce = defaultBrakingForce;
//        _reactor.birthRate = 0;
//    }
    
    if (_engineForce != 0 ){
        _reactor.birthRate = _reactorDefaultBirthRate;
    }
    else {
        _reactor.birthRate = 0;
    }
    
    //update the vehicle steering and acceleration
    [_vehicle setSteeringAngle:_vehicleSteering forWheelAtIndex:0];
    [_vehicle setSteeringAngle:_vehicleSteering forWheelAtIndex:1];
    
    [_vehicle applyEngineForce:_engineForce forWheelAtIndex:2];
    [_vehicle applyEngineForce:_engineForce forWheelAtIndex:3];
    
    [_vehicle applyBrakingForce:_breakForce forWheelAtIndex:2];
    [_vehicle applyBrakingForce:_breakForce forWheelAtIndex:3];

    
    //check if the car is upside down
    [self reorientCarIfNeeded];
    
    // make camera follow the car node
    SCNNode *car = [_vehicleNode presentationNode];
    SCNVector3 carPos = car.position;
    vector_float3 targetPos = {carPos.x, 30., carPos.z + 25.};
    vector_float3 cameraPos = SCNVector3ToFloat3(_cameraNode.position);
    cameraPos = vector_mix(cameraPos, targetPos, (vector_float3)(cameraDamping));
    _cameraNode.position = SCNVector3FromFloat3(cameraPos);
    
    if (scnView.inCarView) {
        //move spot light in front of the camera
        SCNVector3 frontPosition = [scnView.pointOfView.presentationNode convertPosition:SCNVector3Make(0, 0, -30) toNode:nil];
        _spotLightNode.position = SCNVector3Make(frontPosition.x, 80., frontPosition.z);
        _spotLightNode.rotation = SCNVector4Make(1,0,0,-M_PI/2);
    }
    else {
        //move spot light on top of the car
        _spotLightNode.position = SCNVector3Make(carPos.x, 80., carPos.z + 30.);
        _spotLightNode.rotation = SCNVector4Make(1,0,0,-M_PI/2.8);
    }
    
    //speed gauge
    AAPLOverlayScene *overlayScene = (AAPLOverlayScene*)scnView.overlaySKScene;
    overlayScene.speedNeedle.zRotation = -(_vehicle.speedInKilometersPerHour * M_PI / MAX_SPEED);
}

- (void)reorientCarIfNeeded
{
    SCNNode *car = [_vehicleNode presentationNode];
    SCNVector3 carPos = car.position;
    
    // make sure the car isn't upside down, and fix it if it is
    static int ticks = 0;
    static int check = 0;
    ticks++;
    if (ticks == 30) {
        SCNMatrix4 t = car.worldTransform;
        if (t.m22 <= 0.1) {
            check++;
            if (check == 3) {
                static int try = 0;
                try++;
                if (try == 3) {
                    try = 0;
                    
                    //hard reset
                    _vehicleNode.rotation = SCNVector4Make(0, 0, 0, 0);
                    _vehicleNode.position = SCNVector3Make(carPos.x, carPos.y + 10, carPos.z);
                    [_vehicleNode.physicsBody resetTransform];
                }
                else {
                    //try to upturn with an random impulse
                    SCNVector3 pos = SCNVector3Make(-10*((rand()/(float)RAND_MAX)-0.5),0,-10*((rand()/(float)RAND_MAX)-0.5));
                    [_vehicleNode.physicsBody applyForce:SCNVector3Make(0, 300, 0) atPosition:pos impulse:YES];
                }
                
                check = 0;
            }
        }
        else {
            check = 0;
        }
        
        ticks=0;
    }
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskLandscape;
}

- (void)addWoodenBlockToScene:(SCNScene *)scene withImageNamed:(NSString *)imageName atPosition:(SCNVector3)position withScale: (SCNVector3)scale
{
    //create a new node
    SCNNode *block = [SCNNode node];
    
    //place it
    block.position = position;
    
    //attach a box of 5x5x5
    block.geometry = [SCNBox boxWithWidth:scale.x height:scale.y length:scale.z chamferRadius:0];
    
    //use the specified images named as the texture
    block.geometry.firstMaterial.diffuse.contents = imageName;
    
    //turn on mipmapping
    block.geometry.firstMaterial.diffuse.mipFilter = SCNFilterModeLinear;
    
    //make it physically based
    block.physicsBody = [SCNPhysicsBody staticBody];
    
    //add to the scene
    [[scene rootNode] addChildNode:block];
}

//SCNPhysicsContactDelegate

- (void)physicsWorld:(SCNPhysicsWorld *)world didBeginContact:(SCNPhysicsContact *)contact
{
    NSLog(@"@@@@@@@didBeginContact\n");
    
    if ( [contact.nodeA.name isEqualToString:@"rccarBody"] || [contact.nodeB.name isEqualToString:@"rccarBody"] ){
        
        @synchronized(self){
        
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                               didcontact = YES;
                               
                               [[NSNotificationCenter defaultCenter] postNotificationName:@"stopRot" object:nil];
                           });
        
        }
    }
}

- (void)physicsWorld:(SCNPhysicsWorld *)world didUpdateContact:(SCNPhysicsContact *)contact
{
    if ( [contact.nodeA.name isEqualToString:@"rccarBody"] || [contact.nodeB.name isEqualToString:@"rccarBody"] ){
        
        //didcontact = YES;
        NSLog(@"@@@@@@@@didUpdateContact\n");
         //[[NSNotificationCenter defaultCenter] postNotificationName:@"stopRot" object:nil];
    }
}

- (void)physicsWorld:(SCNPhysicsWorld *)world didEndContact:(SCNPhysicsContact *)contact
{
    NSLog(@"@@@@@@@@@@didEndContact\n");
    
    if ( [contact.nodeA.name isEqualToString:@"rccarBody"] || [contact.nodeB.name isEqualToString:@"rccarBody"] ){
        
        @synchronized(self){
            
            dispatch_async(dispatch_get_main_queue(),
                           ^{
                               didcontact = NO;
                               timecount = 0;
                           });
            
        }
    }
}

@end
