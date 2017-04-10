/**
 *
 *	@file   	: uexIAPManager.h  in EUExInAppPurchase
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

#import <Foundation/Foundation.h>

#import <AppCanKit/AppCanKit.h>

typedef NS_ENUM(NSInteger,uexIAPReceiptVerifyStrategy){
    uexIAPReceiptVerifyStrategySandbox = 0,
    uexIAPReceiptVerifyStrategyProduction,
    uexIAPReceiptVerifyStrategyNone,
};


@interface uexIAPManager : NSObject 
@property (nonatomic,weak)__kindof EUExBase * eventObserver;


+ (instancetype)sharedInstance;

- (BOOL)canMakePay;
- (void)getProductList:(NSSet<NSString *> *)productIdentifiers withCallback:(ACJSFunctionRef *)callback;

- (void)purhcaseWithProductID:(NSString *)productIdentifier
                     quantity:(NSInteger)quantity
               verifyStrategy:(uexIAPReceiptVerifyStrategy)verifyStrategy
                     callback:(ACJSFunctionRef *)callback;

- (void)restorePurchase;

@end
