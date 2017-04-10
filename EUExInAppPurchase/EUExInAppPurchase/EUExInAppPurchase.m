/**
 *
 *	@file   	: EUExInAppPurchase.m  in EUExInAppPurchase
 *
 *	@author 	: 杨广,CeriNo
 *
 *	@date   	: Created on 17/3/30.
 *
 *	@copyright 	: 2017 The AppCan Open Source Project.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU Lesser General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU Lesser General Public License for more details.
 *  You should have received a copy of the GNU Lesser General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "EUExInAppPurchase.h"

#import "uexIAPManager.h"



@interface EUExInAppPurchase()
@property(nonatomic,readonly) uexIAPManager *manager;
@end
@implementation EUExInAppPurchase


- (instancetype)initWithWebViewEngine:(id<AppCanWebViewEngineObject>)engine{
    if (self = [super initWithWebViewEngine:engine]) {
    }
    return self;
}


- (uexIAPManager *)manager{
    return [uexIAPManager sharedInstance];
}

- (void)activate{
    self.manager.eventObserver = self;
}


- (void)getProductList:(NSMutableArray *)inArguments {

    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *callback) = inArguments;
    NSArray *productArr = arrayArg(info[@"productIDs"]);
    NSSet *set = [NSSet setWithArray:productArr];
    [self activate];
    [self.manager getProductList:set withCallback:callback];
}



- (void)purchase:(NSMutableArray *)inArguments {

    ACArgsUnpack(NSDictionary *info,ACJSFunctionRef *callback) = inArguments;
    NSString *productIdentifier = stringArg(info[@"productID"]);

    NSInteger quantity = numberArg(info[@"quantity"]).integerValue;
    if (quantity <= 0) {
        quantity = 1;
    }
    
    NSNumber *verifyStrategy = numberArg(info[@"verifyStrategy"]);
    NSNumber *appStoreVerifyURL = numberArg(info[@"appStoreVerifyURL"]);
    uexIAPReceiptVerifyStrategy strategy = uexIAPReceiptVerifyStrategySandbox;
    if (verifyStrategy) {
        strategy = verifyStrategy.integerValue;
    }else if (appStoreVerifyURL && appStoreVerifyURL.boolValue){
        strategy = uexIAPReceiptVerifyStrategyProduction;
    }
    [self activate];
    [self.manager purhcaseWithProductID:productIdentifier quantity:quantity verifyStrategy:strategy callback:callback];
}

- (void)restorePurchase:(NSMutableArray *)inArguments{
    [self activate];
    [self.manager restorePurchase];
}

- (NSNumber *)canMakePay:(NSMutableArray *)inArguments {
    BOOL canPay = [self.manager canMakePay];
    return canPay ? @0 : @1;
}

@end
