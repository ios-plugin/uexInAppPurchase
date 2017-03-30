//
//  uexIAPManager.m
//  EUExInAppPurchase
//
//  Created by 杨广 on 16/5/20.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import "uexIAPManager.h"
#import "EUtility.h"

@implementation uexIAPManager
+ (instancetype)sharedInstance{
    static uexIAPManager *uexManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uexManager = [[self alloc] init];
    });
    return uexManager;
}

-(void)getProductList:(NSSet *)sets Function:(ACJSFunctionRef *)func{
    self.func = func;
    //定义请求用于获取产品
    SKProductsRequest *productRequest=[[SKProductsRequest alloc]initWithProductIdentifiers:sets];
    //设置代理,用于获取产品加载状态
    productRequest.delegate = self;
    //开始请求
    [productRequest start];

}
#pragma mark - SKProductsRequestd代理方法
-(void)requestDidFinish:(SKRequest *)request{
     NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"status"] = @0;
    [self.delegate callBackJsonWithFunction:@"onRequestState" parameter:dic];
}
-(void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"status"] = @1;
    dic[@"errorCode"] = @(error.code);
    dic[@"errorDescription"] = error.localizedDescription;
    [self.delegate callBackJsonWithFunction:@"onRequestState" parameter:dic];
     NSLog(@"请求过程中发生错误，错误信息：%@",error.localizedDescription);
}

/**
 *  产品请求完成后的响应方法
 *
 *  @param request  请求对象
 *  @param response 响应对象，其中包含产品信息
 */
-(void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response{
    //保存有效的产品
    NSMutableArray *procuctsArr=[NSMutableArray array];
    self.productsDic = [NSMutableDictionary dictionary];
    [response.products enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SKProduct *product = obj;
        NSString *price = [NSString stringWithFormat:@"%@",product.price];
        NSDictionary *dic = @{@"productIdentifier":product.productIdentifier,@"localizedTitle":product.localizedTitle,@"price":price,@"localizedDescription":product.localizedDescription};
        [self.productsDic setObject:product forKey:product.productIdentifier];
        [procuctsArr addObject:dic];
    }];
    if (procuctsArr.count > 0) {
        NSLog(@"%@",procuctsArr);
        [self.delegate callBackJsonWithFunction:@"cbGetProductList" parameter:procuctsArr];
        [self.func executeWithArguments:ACArgsPack(@(0),procuctsArr)];
    }else{
        [self.func executeWithArguments:ACArgsPack(@(1),nil)];
    }
    NSLog(@"无效商品列表 ：%@",response.invalidProductIdentifiers);
    
}

-(void)purchaseProductID:(NSString *)productIdentifier verifyURL:(NSString *)verifyURL quantity:(NSInteger)quantity {
    SKProduct *product = self.productsDic[productIdentifier];
    self.verifyURL = verifyURL;
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    if (product) {
        dic[@"status"] = @0;
        dic[@"msg"] = @"purchase start";
        [self.delegate callBackJsonWithFunction:@"onPurchaseState" parameter:dic];
        //创建产品支付对象
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = quantity;
        [[SKPaymentQueue defaultQueue] addTransactionObserver:[uexIAPManager sharedInstance]];
        //添加到支付队列，开始请求支付
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }else{
        dic[@"status"] = @1;
        dic[@"msg"] = @"product is nil";
        [self.delegate callBackJsonWithFunction:@"onPurchaseState" parameter:dic];
    }

    }
-(BOOL)canMakePay{
    
    return [SKPaymentQueue canMakePayments];
    
}
#pragma mark - SKPaymentQueue监听方法
/**
 *  交易状态更新后执行
 *
 *  @param queue        支付队列
 *  @param transactions 交易数组，里面存储了本次请求的所有交易对象
 */
-(void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions{
     NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    [transactions enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SKPaymentTransaction *paymentTransaction =obj;
        if (paymentTransaction.transactionState == SKPaymentTransactionStatePurchased){//已购买成功
            [self verifyPurchaseWithPaymentTransaction];
            //结束支付交易
            [[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
            
        }else if(paymentTransaction.transactionState==SKPaymentTransactionStateRestored){//恢复成功，对于非消耗品才能恢复,如果恢复成功则transaction中记录的恢复的产品交易
            //            NSLog(@"恢复交易\"%@\"成功.",paymentTransaction.payment.productIdentifier);
            dic[@"transactionDate"] = [NSString stringWithFormat:@"%@",paymentTransaction.transactionDate];
            dic[@"transactionIdentifier"] = paymentTransaction.transactionIdentifier;
            dic[@"originalTransaction"] = @{@"productIdentifier":paymentTransaction.originalTransaction.payment.productIdentifier,@"quantity":[NSString stringWithFormat:@"%ld",(long)paymentTransaction.originalTransaction.payment.quantity],@"transactionDate":[NSString stringWithFormat:@"%@",paymentTransaction.originalTransaction.transactionDate]};
            dic[@"productIdentifier"]= paymentTransaction.payment.productIdentifier ;
            dic[@"quantity"] = @(paymentTransaction.payment.quantity);
            dic[@"status"] = @1;//已经购买过该商品
            [self.delegate callBackJsonWithFunction:@"onTransactionState" parameter:dic];
            //结束支付交易
            [[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
            
        }else if(paymentTransaction.transactionState==SKPaymentTransactionStateFailed){
            dic[@"status"] = @2;// @"购买失败";
            dic[@"errorCode"] = @(paymentTransaction.error.code);
            dic[@"errorDescription"] = paymentTransaction.error.localizedDescription;
            dic[@"productIdentifier"]= paymentTransaction.payment.productIdentifier;
            [self.delegate callBackJsonWithFunction:@"onTransactionState" parameter:dic];
            [[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
        }
        
    }];
   
}
-(void)verifyPurchaseWithPaymentTransaction{
    //从沙盒中获取交易凭证并且拼接成请求体数据
    NSURL *receiptUrl=[[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData=[NSData dataWithContentsOfURL:receiptUrl];
    NSString *receiptString=[receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];//转化为base64字符串
    NSString *bodyString = [NSString stringWithFormat:@"{\"receipt-data\" : \"%@\"}", receiptString];//拼接请求数据
    NSData *bodyData = [bodyString dataUsingEncoding:NSUTF8StringEncoding];
    //创建请求到苹果官方进行购买验证
    NSURL *url=[NSURL URLWithString:self.verifyURL];
    NSMutableURLRequest *requestM=[NSMutableURLRequest requestWithURL:url];
    requestM.HTTPBody=bodyData;
    requestM.HTTPMethod=@"POST";
    //创建连接并发送同步请求
    __block NSMutableDictionary *dic = [NSMutableDictionary dictionary];
//    NSData *responseData=[NSURLConnection sendSynchronousRequest:requestM returningResponse:nil error:&error];
//    if (error) {
//        dic[@"status"] = @3;//@"验证购买过程中发生错误"
//        dic[@"errorCode"] = @(error.code);
//        dic[@"errorDescription"] = error.localizedDescription;
//    }else if (responseData == nil){
//        dic[@"status"] = @4;//@"验证购买过程中返回数据为空"
//        dic[@"msg"] = @"responseData is nil";
//    }else{
//       dic = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
//    }
//    [self callBackJsonWithFunction:@"onTransactionState" parameter:dic];
 
    /*------------*/
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLSessionDataTask *task = [session dataTaskWithRequest:requestM completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            if (error) {
                dic[@"status"] = @3;//@"验证购买过程中发生错误"
                dic[@"errorCode"] = @(error.code);
                dic[@"errorDescription"] = error.localizedDescription;
            }else if (data == nil){
                dic[@"status"] = @4;//@"验证购买过程中返回数据为空"
                dic[@"msg"] = @"responseData is nil";
            }else{
                dic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
            }
            [self.delegate callBackJsonWithFunction:@"onTransactionState" parameter:dic];
        }];
    
     [task resume];
    /*------------*/
    
}
//**********************************************************************
-(void)restorePurchase{
     [[SKPaymentQueue defaultQueue] addTransactionObserver:[uexIAPManager sharedInstance]];
    //恢复所有非消耗品
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}
//恢复购买完成
-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"status"] = @0;//恢复购买完成
    [self.delegate callBackJsonWithFunction:@"onRestoreState" parameter:dic];
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
     NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    if (error) {
        dic[@"status"] = @1;//恢复购买失败
        dic[@"errorCode"] = @(error.code);
        dic[@"errorDescription"] = error.localizedDescription;
        [self.delegate callBackJsonWithFunction:@"onRestoreState" parameter:dic];
    }
}
-(void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:[uexIAPManager sharedInstance]];
}

@end
