//
//  EUExInAppPurchase.m

//
//  Created by 杨广 on 16/1/9.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import "EUExInAppPurchase.h"
#import "EUtility.h"
#import "uexIAPManager.h"
//#define kAppStoreVerifyURL @"https://buy.itunes.apple.com/verifyReceipt" //实际购买验证URL
//#define kSandboxVerifyURL @"https://sandbox.itunes.apple.com/verifyReceipt" //开发阶段沙盒验证URL


//定义可以购买的产品ID，必须和iTunes Connect中设置的一致
//#define kProductID1 @"ProtectiveGloves" //强力手套，非消耗品
//#define kProductID2 @"GoldenGlobe" //金球，非消耗品
//#define kProductID3 @"EnergyBottle" //能量瓶，消耗品
@interface EUExInAppPurchase()<CallBackDelegate>
@property(strong,nonatomic) uexIAPManager *manager;
@end
@implementation EUExInAppPurchase

-(id)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    if (self = [super initWithWebViewEngine:engine]) {
        self.manager = [uexIAPManager sharedInstance];
        self.manager.delegate = self;
    }
    return self;
}
-(void)getProductList:(NSMutableArray *)inArguments {
    if (inArguments.count < 1) {
        return;
    }
    ACArgsUnpack(NSDictionary *jsonDict,ACJSFunctionRef*func) = inArguments;
    NSArray *productArr = [jsonDict objectForKey:@"productIDs"];
    //定义要获取的产品标识集合
    NSSet *sets=[NSSet setWithArray:productArr];
    [self.manager getProductList:sets Function:func];
    
}


//*****************************************************************
-(void)purchase:(NSMutableArray *)inArguments {
    if (inArguments.count < 1) {
        return;
    }
    ACArgsUnpack(NSDictionary *jsonDict) = inArguments;
    NSString *productIdentifier =[jsonDict objectForKey:@"productID"];
    NSInteger quantity =[[jsonDict objectForKey:@"quantity"] integerValue]?:1;
    BOOL appStoreVerifyUR = [[jsonDict objectForKey:@"appStoreVerifyURL"] boolValue];
    NSString* verifyURL = appStoreVerifyUR? @"https://buy.itunes.apple.com/verifyReceipt":@"https://sandbox.itunes.apple.com/verifyReceipt";
    [self.manager purchaseProductID:productIdentifier verifyURL:verifyURL quantity:quantity];
    
    
}

-(void)restorePurchase:(NSMutableArray *)inArguments{
    [self.manager restorePurchase];
}

-(NSNumber*)canMakePay:(NSMutableArray *)inArguments {
   BOOL canPay = [self.manager canMakePay];
    return canPay?@(0):@(1);
}
#pragma mark - CallBack Method

-(void)callBackJsonWithFunction:(NSString *)functionName parameter:(id)obj{
    
    [self.webViewEngine callbackWithFunctionKeyPath:[NSString stringWithFormat:@"uexInAppPurchase.%@",functionName] arguments:ACArgsPack([obj ac_JSONFragment])];
    
}
@end
