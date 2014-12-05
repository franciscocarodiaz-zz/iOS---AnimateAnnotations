//
//  ViewController.m
//  AllThePhotoes
//
//  Created by Francisco Caro Diaz on 10/11/14.
//  Copyright (c) 2014 ironhack. All rights reserved.
//

#import "PhotoViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import <AFNetworking.h>
#import "MyLocation.h"

@import CoreBluetooth;
@import AudioToolbox;
@import AVFoundation;

@interface PhotoViewController () <MKMapViewDelegate,UINavigationControllerDelegate, UIImagePickerControllerDelegate,CLLocationManagerDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *theImageView;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic)  BOOL photoIsFromCamera;
@property (weak, nonatomic) IBOutlet UILabel *batteryLabel;
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (nonatomic, strong) CLBeaconRegion *region;
@end

@implementation PhotoViewController

-(void)viewDidAppear:(BOOL)animated{
    // Como encender la linterna.
    //    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    //    [device lockForConfiguration:nil];
    //    [device setTorchMode:AVCaptureTorchModeOn];
    //    [device unlockForConfiguration];
    //    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
    //        [self.locationManager requestWhenInUseAuthorization];
    //    }
    
    self.mapView.showsUserLocation = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    CBCentralManager *testBluetooth = [[CBCentralManager alloc] initWithDelegate:nil queue:nil];
    CBCentralManagerState state = [testBluetooth state];
    
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.mapView.delegate = self;
    // Check for iOS 8. Without this guard the code will crash with "unknown selector" on iOS 7.
    if (CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways || CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self setUpLocationStuff];
    }else{
        [self.locationManager requestWhenInUseAuthorization];
    }
    
    
//    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
//        [self.locationManager requestWhenInUseAuthorization];
//    }
    
    
    
    [self viewBatteryLevel];
    
    
    // Request: My API (https://api.foursquare.com/v2/venues/search?ll=37.589590%2C-5.973473&client_id=UGMNFMZYWFUF3HWJ5UBP4X22MOPFZ4O2E45NRBCOVC0KFW52&client_secret=SSTBW0FHQK42QXDLJFFV0NN1EGUW4HY5C0RNJN0JGGWUQXCE&v=20141113)
    
    NSURL* URL = [NSURL URLWithString:@"https://api.foursquare.com/v2/venues/search?ll=37.589590%2C-5.973473&client_id=UGMNFMZYWFUF3HWJ5UBP4X22MOPFZ4O2E45NRBCOVC0KFW52&client_secret=SSTBW0FHQK42QXDLJFFV0NN1EGUW4HY5C0RNJN0JGGWUQXCE&v=20141113"];
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:URL];
    request.HTTPMethod = @"GET";
    request.timeoutInterval = 30;
    
    // Request Operation
    
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    operation.responseSerializer = [AFJSONResponseSerializer serializer];
    // Progress & Completion blocks
    
    [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
        NSLog(@"Received %lld of %lld bytes", totalBytesRead, totalBytesExpectedToRead);
    }];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Success: Status Code %ld", operation.response.statusCode);
        
        NSArray *arrayOfPlaces = responseObject[@"response"][@"venues"];
        NSMutableArray *arrayOfAnotations = [NSMutableArray array];
        for (int i=0; i<[arrayOfPlaces count]; i++) {
            
            NSNumber * latitude = arrayOfPlaces[i][@"location"][@"lat"];
            NSNumber * longitude = arrayOfPlaces[i][@"location"][@"lng"];
            NSString * crimeDescription = arrayOfPlaces[i][@"name"];
            NSString * address = arrayOfPlaces[i][@"location"][@"country"];
            
            CLLocationCoordinate2D coordinate;
            coordinate.latitude = latitude.doubleValue;
            coordinate.longitude = longitude.doubleValue;
            MyLocation *annotation = [[MyLocation alloc] initWithName:crimeDescription address:address coordinate:coordinate] ;
            //[_mapView addAnnotations:arrayOfAnotations];
            [arrayOfAnotations addObject:annotation];
            [_mapView setRegion:MKCoordinateRegionMakeWithDistance(coordinate, 2000, 2000) animated:YES];
        }
        
        [_mapView addAnnotations:arrayOfAnotations];
        
        
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error.localizedDescription);
    }];
    
    // Connection
    
    [operation start];

}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views {
    MKAnnotationView *aV;
    int i = 0;
    for (aV in views) {
        
        // Don't pin drop if annotation is user location
        if ([aV.annotation isKindOfClass:[MKUserLocation class]]) {
            continue;
        }
        
        // Check if current annotation is inside visible map rect, else go to next one
        MKMapPoint point =  MKMapPointForCoordinate(aV.annotation.coordinate);
        if (!MKMapRectContainsPoint(self.mapView.visibleMapRect, point)) {
            continue;
        }
        
        CGRect endFrame = aV.frame;
        
        // Move annotation out of view
        aV.frame = CGRectMake(aV.frame.origin.x, aV.frame.origin.y - self.view.frame.size.height, aV.frame.size.width, aV.frame.size.height);
        
        // Animate drop
        [UIView animateWithDuration:1.5 delay:0.04*[views indexOfObject:aV] options: UIViewAnimationOptionCurveLinear animations:^{
            
            aV.frame = endFrame;
            
            // Animate squash
        }completion:^(BOOL finished){
            if (finished) {
                [UIView animateWithDuration:0.05 animations:^{
                    aV.transform = CGAffineTransformMakeScale(1.0, 0.8);
                    
                }completion:^(BOOL finished){
                    if (finished) {
                        [UIView animateWithDuration:0.1 animations:^{
                            aV.transform = CGAffineTransformIdentity;
                        }];
                    }
                }];
            }
        }];
    }
}

- (IBAction)notificationButtonPressed:(UIButton *)sender {
    UILocalNotification *localNotification = [[UILocalNotification alloc] init];
    localNotification.fireDate = [NSDate dateWithTimeIntervalSinceNow:10];
    localNotification.alertBody = [NSString stringWithFormat:@"Alert Fired now"];
    localNotification.soundName = UILocalNotificationDefaultSoundName;
    localNotification.applicationIconBadgeNumber = 1;
    [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
}

- (IBAction)switchChanged:(id)sender {
    UISwitch *theSwitch = sender;
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [device lockForConfiguration:nil];
    [device setTorchMode:theSwitch.isOn ? AVCaptureTorchModeOn : AVCaptureTorchModeOff];
    [device unlockForConfiguration];
    
    [[UIDevice currentDevice] setProximityMonitoringEnabled:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(proximityStateChanged) name:UIDeviceProximityStateDidChangeNotification object:nil];
}

-(void)proximityStateChanged{
    [[UIDevice currentDevice] proximityState]; // YES or NO
}

-(void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event{
    if (motion == UIEventSubtypeMotionShake) {
        CGFloat randColorRed = (arc4random()%255)/255.0;
        CGFloat randColorGreen = (arc4random()%255)/255.0;
        CGFloat randColorBlue = (arc4random()%255)/255.0;
        //CGFloat randColorAlpha = (arc4random()%1)/1.0;
        self.view.backgroundColor = [UIColor colorWithRed:randColorRed green:randColorGreen blue:randColorBlue alpha:1.0];
    }
}

-(BOOL)photoIsFromCamera{
    return YES;
}


- (void)viewBatteryLevel {
    self.batteryLabel.text = @"100%";
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    UIDevice *myDevice = [UIDevice currentDevice];
    [myDevice setBatteryMonitoringEnabled:YES];
    double batLeft = (float)[myDevice batteryLevel] * 100;
    NSString * levelLabel = [NSString stringWithFormat:@"%.f%%", batLeft];
    self.batteryLabel.text = levelLabel;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)showPhotosUI:(UIImagePickerControllerSourceType)sourceType {
    if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
        UIImagePickerController* imagePickerController = [[UIImagePickerController alloc] init];
        imagePickerController.delegate = self;
        imagePickerController.sourceType = sourceType;
        //imagePickerController.mediaTypes = [NSArray arrayWithObjects:(NSString *) kUTTypeImage,(NSString *) kUTTypeMovie, nil];
        imagePickerController.allowsEditing = YES;
        [self presentViewController:imagePickerController animated:YES completion:nil];
    }
}

- (IBAction)cameraButtonPressed {
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    self.photoIsFromCamera = YES;
    [self showPhotosUI:sourceType];
}
- (IBAction)libraryButtonPressed:(id)sender {
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    self.photoIsFromCamera = NO;
    [self showPhotosUI:sourceType];
}
- (IBAction)albumButtonPressed:(id)sender {
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
    self.photoIsFromCamera = NO;
    [self showPhotosUI:sourceType];
}

#pragma mark - UIImagePickerControllerDelegate delegate

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{

    UIImage *originalImage = info[UIImagePickerControllerOriginalImage];
    UIImage *image = info[UIImagePickerControllerEditedImage];
    self.theImageView.image = image;
    
    // Get info of image like gps location
    
    NSURL *referenceURL = [info objectForKey:UIImagePickerControllerReferenceURL];
    ALAssetsLibrary *library = [[ALAssetsLibrary alloc] init];
    [library assetForURL:referenceURL resultBlock:^(ALAsset *asset) {
        ALAssetRepresentation *rep = [asset defaultRepresentation];
        NSDictionary *metadata = rep.metadata;
        //NSLog(@"%@", metadata);
        
        /*
        if (metadata[@"{GPS}"]) {
            int latitudeSign;
            NSString *latSignString = metadata[@"{GPS}"][@"LatitudeRef"];
            if ([latSignString isEqualToString:@"N"]) {
                latitudeSign = (int)North;
            } else {
                latitudeSign = (int)South;
            }
            CGFloat latitude = [metadata[@"{GPS}"][@"Latitude"] floatValue] * latitudeSign;
            int longitudeSign;
            NSString *longSignString = metadata[@"{GPS}"][@"LongitudeRef"];
            if ([longSignString isEqualToString:@"E"]) {
                longitudeSign = (int)East;
            } else {
                longitudeSign = (int)West;
            }
            CGFloat longitude = [metadata[@"{GPS}"][@"Longitude"] floatValue] * longitudeSign;
            CLLocationCoordinate2D location= CLLocationCoordinate2DMake(latitude, longitude);
            self.theMap.centerCoordinate = location;
        }
        */
        CGImageRef iref = [rep fullScreenImage] ;
        
        if (iref) {
            self.theImageView.image = [UIImage imageWithCGImage:iref];
        }
    } failureBlock:^(NSError *error) {
        // error handling
    }];
    
    
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    if (self.photoIsFromCamera) {
        
        CIImage *image = [self.theImageView.image CIImage];
        CIContext *context = [CIContext contextWithOptions:nil];
        NSDictionary *opts = @{CIDetectorAccuracy: CIDetectorAccuracyHigh};
        CIDetector *detector = [CIDetector detectorOfType:CIDetectorTypeFace context:context options:opts];
        
        NSArray *features = [detector featuresInImage:image options:opts];
        
        if (features.count>0) {
            CIFeature *cameraPhoto = features[0];
            CGRect bounds = cameraPhoto.bounds;
        }
        
        UIImageWriteToSavedPhotosAlbum(originalImage, self, @selector(image:finishedSavingWithError:contextInfo:), nil);
    }
    
    // Hacer vibrar el movil.
    [self simpleVibration];
    
    // Lanzar un audio.
    [self saySomething];
    

}

-(void)image:(UIImage *)image finishedSavingWithError:(NSError *)error contextInfo:(void *)contextInfo{
    //Error saving to camera roll
    if (error) {
        //Notify error
    }
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

-(void)simpleVibration{
    AudioServicesPlayAlertSound(kSystemSoundID_Vibrate);
}

-(void)saySomething{
    NSString *savedString = @"How cool is that!!!!";
    AVSpeechSynthesizer *synth = [[AVSpeechSynthesizer alloc] init];
    AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:savedString] ;
    //AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"es_ES"];
    NSString *currentLanguageCode = [AVSpeechSynthesisVoice currentLanguageCode];
    AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:currentLanguageCode];
    [utterance setVoice:voice];
    [utterance setRate:0.1];
    [synth speakUtterance:utterance];
}


#pragma mark Location Delegate


// Location Manager Delegate Methods
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    NSLog(@"%@", [locations lastObject]);
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = @"Are you forgetting something?";
    notification.soundName = @"Default";
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}

- (void)setUpLocationStuff {
    self.region = [[CLBeaconRegion alloc] initWithProximityUUID:[[NSUUID alloc] initWithUUIDString:@"8492e75f-4fd6-469d-b132-043fe94921d8"] identifier:@"pwpowphone"];
    [self.locationManager startMonitoringForRegion:self.region];
    
    // Real location
    CLRegion *realRegion = [[CLCircularRegion alloc] initWithCenter:CLLocationCoordinate2DMake(42, 2) radius:200 identifier:@"lost in cataluña"];
    [self.locationManager startMonitoringForRegion:realRegion];
    
    
    [self.locationManager startUpdatingLocation];
}

-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status{

    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        
        if (!self.region) {
            [self setUpLocationStuff];
        }
        
        
    }

}

#pragma mark iBeacons Delegate

-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region{
    NSLog(@"%@", [beacons firstObject]);
    if ([region.identifier isEqualToString:@"pwpowphone"]) {
        CLBeacon *beacon = beacons[0];
        NSLog(@"major:%@, minor:%@",beacon.major,beacon.minor);
        NSLog(@"Proximity:%ld", beacon.proximity);
    }
}

-(void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region{

}

-(void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region{
    NSLog(@"Region:%@",region.identifier);
}


@end
