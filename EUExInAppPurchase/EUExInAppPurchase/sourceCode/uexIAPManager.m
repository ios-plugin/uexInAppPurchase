/**
 *
 *	@file   	: uexIAPManager.m  in EUExInAppPurchase
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

#import "uexIAPManager.h"
#import <StoreKit/StoreKit.h>
#import <objc/runtime.h>

#define UexDefine(__class,__name) \
    property (nonatomic, strong, setter=set__##__name:, getter=__##__name) __class __name;

#define UexSynthesize(__class,__name) \
    dynamic __name;\
    \
    - (__class)metamacro_concat(__,__name){\
        return objc_getAssociatedObject(self,_cmd);\
    }\
    \
    - (void)metamacro_concat(set__,__name):(__class)__name{\
        objc_setAssociatedObject(self, @selector(metamacro_concat(__,__name)), __name, OBJC_ASSOCIATION_RETAIN_NONATOMIC);\
    }






@interface SKProductsRequest (uexIAP)
@UexDefine(ACJSFunctionRef *,uexIAP_callback);
@end
@implementation SKProductsRequest (uexIAP)
@UexSynthesize(ACJSFunctionRef *,uexIAP_callback);
@end

@interface uexIAPPaymentInfo : NSObject
@property (nonatomic, strong) ACJSFunctionRef *callback;
@property (nonatomic, assign) uexIAPReceiptVerifyStrategy verifyStrategy;
@property (nonatomic, strong) SKPayment *payment;
@end
@implementation uexIAPPaymentInfo

@end

@interface uexIAPManager()<SKProductsRequestDelegate,SKPaymentTransactionObserver>
@property (nonatomic, strong) NSMutableDictionary<NSString *,SKProduct *> *products;//有效的产品
@property (nonatomic, strong) NSMutableDictionary<NSString *,uexIAPPaymentInfo *> *payments;
@property (nonatomic, strong) NSString *verifyURL;

@end

@implementation uexIAPManager
+ (instancetype)sharedInstance{
    static uexIAPManager *uexManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uexManager = [[self alloc] init];
    });
    return uexManager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        _payments = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)canMakePay{
    return [SKPaymentQueue canMakePayments];
}

- (void)getProductList:(NSSet<NSString *> *)productIdentifiers withCallback:(ACJSFunctionRef *)callback{
    SKProductsRequest *request = [[SKProductsRequest alloc]initWithProductIdentifiers:productIdentifiers];
    request.uexIAP_callback = callback;
    request.delegate = self;
    [request start];
}
- (void)purhcaseWithProductID:(NSString *)productIdentifier
                     quantity:(NSInteger)quantity
               verifyStrategy:(uexIAPReceiptVerifyStrategy)verifyStrategy
                     callback:(ACJSFunctionRef *)callback{
    SKProduct *product = self.products[productIdentifier];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"productIdentifier"] = productIdentifier;
    if (!product) {
        NSString *msg = @"product not found";
        dict[@"status"] = @1;
        dict[@"msg"] = msg;
        [self callbackWithFunctionName:@"onPurchaseState" jsonParameters:dict];
        [callback executeWithArguments:ACArgsPack(uexErrorMake(1,msg,dict),msg)];
    }else{
        dict[@"status"] = @0;
        dict[@"msg"] = @"purchase start";
        [self callbackWithFunctionName:@"onPurchaseState" jsonParameters:dict];
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = quantity;
        uexIAPPaymentInfo *info = [[uexIAPPaymentInfo alloc]init];
        info.payment = payment;
        info.callback = callback;
        info.verifyStrategy = verifyStrategy;
        NSString *uuid = [NSUUID UUID].UUIDString;
        self.payments[uuid] = info;
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}




-(void)restorePurchase{
    [[SKPaymentQueue defaultQueue] addTransactionObserver:[uexIAPManager sharedInstance]];
    //恢复所有非消耗品
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

#pragma mark - SKPaymentTransactionObserver

-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions{
    
    [transactions enumerateObjectsUsingBlock:^(SKPaymentTransaction *transaction, NSUInteger idx, BOOL *stop) {
        
        
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                break;
            case SKPaymentTransactionStatePurchased:{
                [self onTransactionFinished:transaction];
            }
                break;
            case SKPaymentTransactionStateFailed:{
                [self onTransactionFailed:transaction];
            }
                break;
            case SKPaymentTransactionStateRestored:{
                [self onTransactionRestored:transaction];
            }
                break;
            case SKPaymentTransactionStateDeferred:
                break;
        }
    }];
   
}



//恢复购买完成
-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"status"] = @0;//恢复购买完成
    [self callbackWithFunctionName:@"onRestoreState" jsonParameters:dic];
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
     NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    if (error) {
        dic[@"status"] = @1;//恢复购买失败
        dic[@"errorCode"] = @(error.code);
        dic[@"errorDescription"] = error.localizedDescription;
        [self callbackWithFunctionName:@"onRestoreState" jsonParameters:dic];
    }
}


#pragma mark - SKProductsRequestDelegate

- (void)requestDidFinish:(SKRequest *)request{
    [self callbackWithFunctionName:@"onRequestState" jsonParameters:@{@"status": @0}];
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"status"] = @1;
    dic[@"errorCode"] = @(error.code);
    dic[@"errorDescription"] = error.localizedDescription;
    [self callbackWithFunctionName:@"onRequestState" jsonParameters:dic];
    
    if ([request isKindOfClass:[SKProductsRequest class]]) {
        ACJSFunctionRef *callback = ((SKProductsRequest *)request).uexIAP_callback;
        [callback executeWithArguments:ACArgsPack(uexErrorMake(1,error.localizedDescription))];
    }
}

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    //保存有效的产品
    NSMutableArray *procuctsArr = [NSMutableArray array];
    self.products = [NSMutableDictionary dictionary];
    [response.products enumerateObjectsUsingBlock:^(SKProduct *product, NSUInteger idx, BOOL *stop) {
        NSMutableDictionary *dic = [NSMutableDictionary dictionary];
        dic[@"productIdentifier"] = product.productIdentifier;
        dic[@"localizedTitle"] = product.localizedTitle;
        dic[@"price"] = product.price.stringValue;
        dic[@"localizedDescription"] = product.localizedDescription;
        [self.products setObject:product forKey:product.productIdentifier];
        [procuctsArr addObject:dic];
    }];
    
    [self callbackWithFunctionName:@"cbGetProductList" jsonParameters:procuctsArr];
    [request.uexIAP_callback executeWithArguments:ACArgsPack(@0,procuctsArr)];
    
    
    if (response.invalidProductIdentifiers.count > 0) {
        ACLogDebug(@"无效商品列表 ：%@",response.invalidProductIdentifiers);
    }
}

#pragma mark - Private

- (void)callbackWithFunctionName:(NSString *)funcName jsonParameters:(id)jsonObj{
    NSString *keyPath = [NSString stringWithFormat:@"uexInAppPurchase.%@",funcName];
    
    [self.eventObserver.webViewEngine callbackWithFunctionKeyPath:keyPath arguments:ACArgsPack([jsonObj ac_JSONFragment])];
}

static NSMutableDictionary *parseTransaction(SKPaymentTransaction *transaction){
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    dict[@"transactionDate"] = transaction.transactionDate.description;
    dict[@"transactionIdentifier"] = transaction.transactionIdentifier;
    dict[@"quantity"] = @(transaction.payment.quantity);
    dict[@"productIdentifier"] = transaction.payment.productIdentifier;
    if (transaction.originalTransaction && transaction.originalTransaction.transactionIdentifier != transaction.transactionIdentifier) {
        dict[@"originalTransaction"] = parseTransaction(transaction.originalTransaction);
    }
    return dict;
}

- (uexIAPPaymentInfo *)getPaymentInfo:(SKPaymentTransaction *)transaction{
    SKPayment *payment = transaction.payment;
    __block NSString *uuid = nil;
    __block uexIAPPaymentInfo *info = nil;

    [self.payments enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, uexIAPPaymentInfo * _Nonnull obj, BOOL * _Nonnull stop) {
        if (![payment.productIdentifier isEqual:obj.payment.productIdentifier] || obj.payment.quantity != payment.quantity) {
            return;
        }
        if (payment.applicationUsername && ![payment.applicationUsername isEqual:obj.payment.applicationUsername]) {
            return;
        }
        info = obj;
        uuid = key;
        *stop = YES;
    }];
    if (uuid) {
        self.payments[uuid] = nil;
    }
    
    return info;
}


- (void)onTransactionFinished:(SKPaymentTransaction *)transaction{

    
    uexIAPPaymentInfo *info = [self getPaymentInfo:transaction];
    ACJSFunctionRef *callback = info.callback;
    uexIAPReceiptVerifyStrategy strategy = info.verifyStrategy;
    
    //从沙盒中获取交易凭证并且拼接成请求体数据
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    NSString *receiptString = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    

    
    
    NSURL *url;
    
    switch (strategy) {
        case uexIAPReceiptVerifyStrategyNone:{
            NSMutableDictionary *dict = parseTransaction(transaction);
            dict[@"receiptData"] = receiptString;
            dict[@"status"] = @0;
            [callback executeWithArguments:ACArgsPack(kUexNoError,dict)];
            [self callbackWithFunctionName:@"onTransactionState" jsonParameters:dict];
            
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
        }
            return;
        case uexIAPReceiptVerifyStrategySandbox:
            url = [NSURL URLWithString:@"https://sandbox.itunes.apple.com/verifyReceipt"];
            break;
        case uexIAPReceiptVerifyStrategyProduction:
            url = [NSURL URLWithString:@"https://buy.itunes.apple.com/verifyReceipt"];
            break;
    }
    
    void (^failureCallback)(NSInteger errorCode,NSString *errorMessage) = ^(NSInteger errorCode,NSString *errorMessage){
        NSMutableDictionary *dict = parseTransaction(transaction);
        dict[@"status"] = @3;
        dict[@"errorCode"] = @(errorCode);
        dict[@"errorDescription"] = errorMessage;
        [self callbackWithFunctionName:@"onTransactionState" jsonParameters:dict];
        [callback executeWithArguments:ACArgsPack(uexErrorMake(3,errorMessage),errorMessage)];
    };
    
    
    NSMutableDictionary *bodyDict = [NSMutableDictionary dictionary];
    bodyDict[@"receipt-data"] = receiptString;
    NSError *error = nil;
    NSData *body = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&error];
    if (!body || error) {
        failureCallback(error.code,error.localizedDescription);
        return;
    }

    NSMutableURLRequest *request=[NSMutableURLRequest requestWithURL:url];
    request.HTTPBody = body;
    request.HTTPMethod = @"POST";

    NSURLSession *session = [NSURLSession sharedSession];
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (error) {
            failureCallback(error.code,error.localizedDescription);
            return;
        }
        NSError *e = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:&e];
        if (!dict || ![dict isKindOfClass:[NSDictionary class]] || e) {
            failureCallback(4,@"responseData invalid");
            return;
        }
        [self callbackWithFunctionName:@"onTransactionState" jsonParameters:dict];
        [callback executeWithArguments:ACArgsPack(kUexNoError,dict)];
    }];
    [task resume];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

- (void)onTransactionFailed:(SKPaymentTransaction *)transaction{

    
    NSMutableDictionary *dict = parseTransaction(transaction);
    dict[@"status"] = @2;
    dict[@"errorCode"] = @(transaction.error.code);
    dict[@"errorDescription"] = transaction.error.localizedDescription;
    [self callbackWithFunctionName:@"onTransactionState" jsonParameters:dict];
    uexIAPPaymentInfo *info = [self getPaymentInfo:transaction];
    ACJSFunctionRef *callback = info.callback;
    
    [callback executeWithArguments:ACArgsPack(uexErrorMake(2,transaction.error.localizedDescription),transaction.error.localizedDescription)];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}




- (void)onTransactionRestored:(SKPaymentTransaction *)transaction{
    NSMutableDictionary *dict = parseTransaction(transaction);
    dict[@"status"] = @1;//已经购买过该商品
    [self callbackWithFunctionName:@"onTransactionState" jsonParameters:dict];
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

@end
