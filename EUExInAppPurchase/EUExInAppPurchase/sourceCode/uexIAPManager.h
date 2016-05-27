//
//  uexIAPManager.h
//  EUExInAppPurchase
//
//  Created by 杨广 on 16/5/20.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import "EUExBase.h"
@interface uexIAPManager : NSObject <SKProductsRequestDelegate,SKPaymentTransactionObserver>
@property (strong,nonatomic) NSMutableDictionary *productsDic;//有效的产品
@property (strong,nonatomic) EBrowserView *meBrwView;
@property (strong,nonatomic) NSString *verifyURL;
+ (id)sharedInstance;
-(void)initWithBView:(EBrowserView *)meBrwView;
-(void)getProductList:(NSSet *)sets;
-(void)purchaseProductID:(NSString *)productIdentifier verifyURL:(NSString *)verifyURL quantity:(NSInteger)quantity;
-(void)restorePurchase;
-(BOOL)canMakePay;
@end
