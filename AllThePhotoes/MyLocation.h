//
//  MyLocation.h
//  seff2014
//
//  Created by Francisco Caro Diaz on 30/10/14.
//  Copyright (c) 2014 arequa. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface MyLocation : NSObject <MKAnnotation>

- (id)initWithName:(NSString*)name address:(NSString*)address coordinate:(CLLocationCoordinate2D)coordinate;
//- (MKMapItem*)mapItem;

@end
