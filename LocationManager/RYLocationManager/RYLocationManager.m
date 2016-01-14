//
//  RYLocationManager.m
//  LocationManager
//
//  Created by xiaerfei on 15/11/2.
//  Copyright (c) 2015年 RongYu100. All rights reserved.
//

#import "RYLocationManager.h"

NSString * const RYLocationManagerDidSuccessedLocateNotification = @"LocationManagerDidSuccessedLocateNotification";
NSString * const RYLocationManagerDidFailedLocateNotification    = @"LocationManagerDidFailedLocateNotification";

#define IS_OS_8_OR_LATER ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)

@interface RYLocationManager ()

@property (nonatomic, strong) CLGeocoder *geoCoder;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, copy, readwrite) CLLocation *locatedCityLocation;

@property (nonatomic, assign, readwrite) RYLocationManagerLocationResult        locationResult;
@property (nonatomic, assign, readwrite) RYLocationManagerLocationServiceStatus locationStatus;

@property (nonatomic, copy, readwrite) NSString *state;
@property (nonatomic, copy, readwrite) NSString *city;
@property (nonatomic, copy, readwrite) NSString *subLocality;
@property (nonatomic, copy, readwrite) NSString *street;
@property (nonatomic, copy, readwrite) NSString *formattedAddressLines;


//定位成功之后就不需要再通知到外面了，防止外面的数据变化。
@property (nonatomic) BOOL shouldNotifyOtherObjects;

@end

@implementation RYLocationManager

#pragma mark - life cycle
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.locationResult = RYLocationManagerLocationResultDefault;
        self.locationStatus = RYLocationManagerLocationServiceStatusDefault;
        self.shouldNotifyOtherObjects = YES;
    }
    return self;
}

#pragma mark - public methods
+ (instancetype)sharedInstance
{
    static dispatch_once_t RYLocationManagerOnceToken;
    static RYLocationManager *sharedInstance = nil;
    dispatch_once(&RYLocationManagerOnceToken, ^{
        sharedInstance = [[RYLocationManager alloc] init];
        [sharedInstance startLocation];
    });
    return sharedInstance;
}


- (BOOL)checkLocationAndShowingAlert:(BOOL)showingAlert;
{
    BOOL result = NO;
    //定位是否可用
    BOOL serviceEnable = [self locationServiceEnabled];
    //此时定位的状态
    RYLocationManagerLocationServiceStatus authorizationStatus = [self locationServiceStatus];
    
    if (authorizationStatus == RYLocationManagerLocationServiceStatusOK && serviceEnable) {
        result = YES;
    } else if (authorizationStatus == RYLocationManagerLocationServiceStatusNotDetermined) {
        result = YES;
    } else {
        result = NO;
    }
    
    if (serviceEnable && result) {
        result = YES;
    } else {
        result = NO;
    }
    
    if (result == NO) {
        [self failedLocationWithResultType:RYLocationManagerLocationResultFail statusType:self.locationStatus];
    }
    
    if (showingAlert && result == NO) {
        NSString *message = @"请到“设置->隐私->定位服务”中开启定位";
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"当前定位服务不可用" message:message delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
    }
    
    return result;
}

- (void)startLocation
{
    if ([self checkLocationAndShowingAlert:NO]) {
        self.locationResult = RYLocationManagerLocationResultLocating;
        if(IS_OS_8_OR_LATER) {
            [self.locationManager requestWhenInUseAuthorization];
        }
        [self.locationManager startUpdatingLocation];
    } else {
        [self failedLocationWithResultType:RYLocationManagerLocationResultFail statusType:self.locationStatus];
    }
}

- (void)stopLocation
{
    if ([self checkLocationAndShowingAlert:NO]) {
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)restartLocation
{
    [self stopLocation];
    [self startLocation];
}

#pragma mark - CLLocationManagerDelegate
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    //一开始启动的时候会跑到这边4次。所以如果以后的坐标都不变的话，后面的逻辑也就没必要再跑了。
    if (manager.location.coordinate.latitude == self.locatedCityLocation.coordinate.latitude && manager.location.coordinate.longitude == self.locatedCityLocation.coordinate.longitude) {
        return;
    }
    
    [self fetchCityInfoWithLocation:manager.location geocoder:self.geoCoder];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    //之前如果有定位成功的话，以后的定位失败就都不通知到外面了
    if (!self.shouldNotifyOtherObjects) {
        return;
    }
    
    //如果用户还没选择是否允许定位，则不认为是定位失败
    if (self.locationStatus == RYLocationManagerLocationServiceStatusNotDetermined) {
        return;
    }
    
    //如果正在定位中，那么也不会通知到外面
    if (self.locationResult == RYLocationManagerLocationResultLocating) {
        return;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:RYLocationManagerDidFailedLocateNotification object:nil userInfo:nil];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    if (status == kCLAuthorizationStatusAuthorizedWhenInUse || status == kCLAuthorizationStatusAuthorizedAlways) {
        self.locationStatus = RYLocationManagerLocationServiceStatusOK;
        [self restartLocation];
    } else {
        if (self.locationStatus != RYLocationManagerLocationServiceStatusNotDetermined) {
            [self failedLocationWithResultType:RYLocationManagerLocationResultDefault statusType:RYLocationManagerLocationServiceStatusNoAuthorization];
        }
    }
}

#pragma mark - private methods
- (void)failedLocationWithResultType:(RYLocationManagerLocationResult)result statusType:(RYLocationManagerLocationServiceStatus)status
{
    self.locationResult = result;
    self.locationStatus = status;
    [self locationManager:self.locationManager didFailWithError:nil];
}
/**
 *   @author xiaerfei, 16-01-14 11:01:02
 *
 *   定位是否可用
 *
 *   @return BOOL
 */
- (BOOL)locationServiceEnabled
{
    if ([CLLocationManager locationServicesEnabled]) {
        self.locationStatus = RYLocationManagerLocationServiceStatusOK;
        return YES;
    } else {
        self.locationStatus = RYLocationManagerLocationServiceStatusUnAvailable;
        return NO;
    }
}

- (RYLocationManagerLocationServiceStatus)locationServiceStatus
{
    self.locationStatus = RYLocationManagerLocationServiceStatusUnknownError;
    BOOL serviceEnable = [CLLocationManager locationServicesEnabled];
    if (serviceEnable) {
        CLAuthorizationStatus authorizationStatus = [CLLocationManager authorizationStatus];
        switch (authorizationStatus) {
            case kCLAuthorizationStatusNotDetermined:
                self.locationStatus = RYLocationManagerLocationServiceStatusNotDetermined;
                break;
            case kCLAuthorizationStatusAuthorizedAlways:
            case kCLAuthorizationStatusAuthorizedWhenInUse:
                self.locationStatus = RYLocationManagerLocationServiceStatusOK;
                break;
                
            case kCLAuthorizationStatusDenied:
                self.locationStatus = RYLocationManagerLocationServiceStatusNoAuthorization;
                break;
                
            default:
                if (![self isReachable]) {
                    self.locationStatus = RYLocationManagerLocationServiceStatusNoNetwork;
                }
                break;
        }
    } else {
        self.locationStatus = RYLocationManagerLocationServiceStatusUnAvailable;
    }
    return self.locationStatus;
}

- (void)fetchCityInfoWithLocation:(CLLocation *)location geocoder:(CLGeocoder *)geocoder
{
    [geocoder reverseGeocodeLocation:location completionHandler:^(NSArray *placemarks, NSError *error) {
        
        CLPlacemark *placemark              = [placemarks lastObject];
        if (placemark) {
            NSDictionary *addressDictionary = placemark.addressDictionary;
            self.state                      = addressDictionary[@"State"];
            self.city                       = addressDictionary[@"City"];
            self.subLocality                = addressDictionary[@"SubLocality"];
            self.street                     = addressDictionary[@"Street"];
            self.formattedAddressLines      = [addressDictionary[@"FormattedAddressLines"] lastObject];
            self.locatedCityLocation        = location;
            self.locationResult             = RYLocationManagerLocationResultSuccess;
            self.shouldNotifyOtherObjects   = NO;
            
            NSDictionary *addressParams = @{@"State"                :self.state                 == nil ? @"":self.state,
                                            @"City"                 :self.city                  == nil ? @"":self.city,
                                            @"SubLocality"          :self.subLocality           == nil ? @"":self.subLocality,
                                            @"Street"               :self.street                == nil ? @"":self.street,
                                            @"FormattedAddressLines":self.formattedAddressLines == nil ? @"":self.formattedAddressLines,
                                            @"Location"             :self.locatedCityLocation   == nil ? @"":self.locatedCityLocation};
            
            [[NSNotificationCenter defaultCenter] postNotificationName:RYLocationManagerDidSuccessedLocateNotification object:self userInfo:addressParams];
        } else {
            [self failedLocationWithResultType:RYLocationManagerLocationResultFail statusType:self.locationStatus];
        }
    }];
}

/**
 *   @author xiaerfei, 15-11-02 18:11:45
 *
 *   网络状态
 *
 *   @return
 */
- (BOOL)isReachable
{
    return YES;
}

#pragma mark - getters and setters
- (CLGeocoder *)geoCoder
{
    if (_geoCoder == nil) {
        _geoCoder = [[CLGeocoder alloc] init];
    }
    return _geoCoder;
}

- (CLLocationManager *)locationManager
{
    if (_locationManager == nil) {
        _locationManager = [[CLLocationManager alloc] init];
        _locationManager.delegate = self;
        _locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    }
    return _locationManager;
}

@end

/*
 State:河南省
 City:驻马店市
 SubLocality:驿城区
 Street:前进路二巷
 
 State:上海市
 City:上海市
 SubLocality:徐汇区
 Street:宛平南路850号
 FormattedAddressLines:中国上海市徐汇区枫林路街道宛平南路850号
 */