//
//  uexIAPManager.h
//  EUExInAppPurchase
//
//  Created by 杨广 on 16/5/20.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>
#import <AppCanKit/AppCanKit.h>
@protocol CallBackDelegate <NSObject>
-(void)callBackJsonWithFunction:(NSString *)functionName parameter:(id)obj;
@end
@interface uexIAPManager : NSObject <SKProductsRequestDelegate,SKPaymentTransactionObserver>
@property (strong,nonatomic) NSMutableDictionary *productsDic;//有效的产品
@property (nonatomic, weak) id<CallBackDelegate> delegate;
@property (strong,nonatomic) NSString *verifyURL;
@property (nonatomic,strong) ACJSFunctionRef*func;
+ (instancetype)sharedInstance;
-(void)getProductList:(NSSet *)sets Function:(ACJSFunctionRef*)func;
-(void)purchaseProductID:(NSString *)productIdentifier verifyURL:(NSString *)verifyURL quantity:(NSInteger)quantity;
-(void)restorePurchase;
-(BOOL)canMakePay;
@end
