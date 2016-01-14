//
//  RYLocationManager.h
//  LocationManager
//
//  Created by xiaerfei on 15/11/2.
//  Copyright (c) 2015年 RongYu100. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>


extern NSString * const RYLocationManagerDidSuccessedLocateNotification;
extern NSString * const RYLocationManagerDidFailedLocateNotification;

typedef NS_ENUM(NSUInteger, RYLocationManagerLocationResult) {
    RYLocationManagerLocationResultDefault,              //默认状态
    RYLocationManagerLocationResultLocating,             //定位中
    RYLocationManagerLocationResultSuccess,              //定位成功
    RYLocationManagerLocationResultFail,                 //定位失败
    RYLocationManagerLocationResultParamsError,          //调用API的参数错了
    RYLocationManagerLocationResultTimeout,              //超时
    RYLocationManagerLocationResultNoNetwork,            //没有网络
    RYLocationManagerLocationResultNoContent             //API没返回数据或返回数据是错的
};

typedef NS_ENUM(NSUInteger, RYLocationManagerLocationServiceStatus) {
    RYLocationManagerLocationServiceStatusDefault,               //默认状态
    RYLocationManagerLocationServiceStatusOK,                    //定位功能正常
    RYLocationManagerLocationServiceStatusUnknownError,          //未知错误
    RYLocationManagerLocationServiceStatusUnAvailable,           //定位功能关掉了
    RYLocationManagerLocationServiceStatusNoAuthorization,       //定位功能打开，但是用户不允许使用定位
    RYLocationManagerLocationServiceStatusNoNetwork,             //没有网络
    RYLocationManagerLocationServiceStatusNotDetermined          //用户还没做出是否要允许应用使用定位功能的决定，第一次安装应用的时候会提示用户做出是否允许使用定位功能的决定
};




@interface RYLocationManager : NSObject <CLLocationManagerDelegate>


@property (nonatomic, assign, readonly) RYLocationManagerLocationResult        locationResult;
@property (nonatomic, assign, readonly) RYLocationManagerLocationServiceStatus locationStatus;

@property (nonatomic, copy, readonly) CLLocation *locatedCityLocation;

@property (nonatomic, copy, readonly) NSString *state;
@property (nonatomic, copy, readonly) NSString *city;
@property (nonatomic, copy, readonly) NSString *subLocality;
@property (nonatomic, copy, readonly) NSString *street;
@property (nonatomic, copy, readonly) NSString *formattedAddressLines;

+ (instancetype)sharedInstance;

- (BOOL)checkLocationAndShowingAlert:(BOOL)showingAlert;


- (void)startLocation;
- (void)stopLocation;
- (void)restartLocation;


@end




