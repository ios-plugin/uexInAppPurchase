//
//  EUExInAppPurchase.h
//  EUExInAppPurchase
//
//  Created by 杨广 on 16/1/9.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EUExBase.h"
#import <StoreKit/StoreKit.h>
@interface EUExInAppPurchase : EUExBase<SKProductsRequestDelegate,SKPaymentTransactionObserver>
@property (strong,nonatomic) NSMutableDictionary *productsDic;//有效的产品
@property (strong,nonatomic) NSMutableDictionary *dic;
@property (strong,nonatomic) NSString *verifyURL;
@property BOOL isShow;
@end

