//
//  EUExInAppPurchase.m

//
//  Created by 杨广 on 16/1/9.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import "EUExInAppPurchase.h"
#import "JSON.h"
#import "EUtility.h"
#import "uexIAPManager.h"
//#define kAppStoreVerifyURL @"https://buy.itunes.apple.com/verifyReceipt" //实际购买验证URL
//#define kSandboxVerifyURL @"https://sandbox.itunes.apple.com/verifyReceipt" //开发阶段沙盒验证URL


//定义可以购买的产品ID，必须和iTunes Connect中设置的一致
//#define kProductID1 @"ProtectiveGloves" //强力手套，非消耗品
//#define kProductID2 @"GoldenGlobe" //金球，非消耗品
//#define kProductID3 @"EnergyBottle" //能量瓶，消耗品

@implementation EUExInAppPurchase
-(id)initWithBrwView:(EBrowserView *) eInBrwView {
    if (self = [super initWithBrwView:eInBrwView]) {
        [[uexIAPManager sharedInstance] initWithBView:self.meBrwView];
    }
    return self;
}
-(void)getProductList:(NSMutableArray *)inArguments {
    
    NSString *jsonStr = nil;
    NSMutableDictionary*  jsonDict = [NSMutableDictionary dictionary];
    if (inArguments.count > 0) {
        jsonStr = [inArguments objectAtIndex:0];
        jsonDict = [jsonStr JSONValue];//将JSON类型的字符串转化为可变字典
        
    }else{
        return;
    }
    NSArray *productArr = [jsonDict objectForKey:@"productIDs"];
    //定义要获取的产品标识集合
    NSSet *sets=[NSSet setWithArray:productArr];
    [[uexIAPManager sharedInstance] getProductList:sets];
    
}


//*****************************************************************
-(void)purchase:(NSMutableArray *)inArguments {
    NSString *jsonStr = nil;
    NSMutableDictionary*  jsonDict = [NSMutableDictionary dictionary];
    if (inArguments.count > 0) {
        jsonStr = [inArguments objectAtIndex:0];
        jsonDict = [jsonStr JSONValue];//将JSON类型的字符串转化为可变字典
        
    }else{
        return;
    }
    NSString *productIdentifier =[jsonDict objectForKey:@"productID"];
    NSInteger quantity =[[jsonDict objectForKey:@"quantity"] integerValue]?:1;
    BOOL appStoreVerifyUR = [[jsonDict objectForKey:@"appStoreVerifyURL"] boolValue];
    NSString* verifyURL = appStoreVerifyUR? @"https://buy.itunes.apple.com/verifyReceipt":@"https://sandbox.itunes.apple.com/verifyReceipt";
    [[uexIAPManager sharedInstance] purchaseProductID:productIdentifier verifyURL:verifyURL quantity:quantity];
    
    
}

-(void)restorePurchase:(NSMutableArray *)inArguments{
    [[uexIAPManager sharedInstance] restorePurchase];
}

-(NSNumber*)canMakePay:(NSMutableArray *)inArguments {
   BOOL canPay = [[uexIAPManager sharedInstance] canMakePay];
    return canPay?@(0):@(1);
}
@end
