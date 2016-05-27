//
//  uexIAPManager.m
//  EUExInAppPurchase
//
//  Created by 杨广 on 16/5/20.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import "uexIAPManager.h"
#import "EUtility.h"
#import "JSON.h"
@implementation uexIAPManager
+ (id)sharedInstance {
    //创建一个静态的空的单例对象
    static uexIAPManager *uexManager = nil;
    //声明一个静态的gcd的单次任务
    static dispatch_once_t onceToken;
    //执行单次任务；
    dispatch_once(&onceToken, ^{
        //对对象进行初始化
        uexManager = [[self alloc] init];
    });
    
    return uexManager;
}
-(void)initWithBView:(EBrowserView *)meBrwView{
    self.meBrwView = meBrwView;
}
-(void)getProductList:(NSSet *)sets{
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
    [self callBackJsonWithFunction:@"onRequestState" parameter:dic];
}
-(void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    dic[@"status"] = @1;
    dic[@"errorCode"] = @(error.code);
    dic[@"errorDescription"] = error.localizedDescription;
    [self callBackJsonWithFunction:@"onRequestState" parameter:dic];
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
        //                 NSLog(@"%@",product.localizedDescription);
        //                 NSLog(@"%@",product.localizedTitle);
        //                 NSLog(@"%@",product.price);
        //                 NSLog(@"%@",product.productIdentifier);
        NSString *price = [NSString stringWithFormat:@"%@",product.price];
        NSDictionary *dic = @{@"productIdentifier":product.productIdentifier,@"localizedTitle":product.localizedTitle,@"price":price,@"localizedDescription":product.localizedDescription};
        [self.productsDic setObject:product forKey:product.productIdentifier];
        [procuctsArr addObject:dic];
    }];
    if (procuctsArr.count > 0) {
        [self callBackJsonWithFunction:@"cbGetProductList" parameter:procuctsArr];
    }
    NSLog(@"无效商品列表 ：%@",response.invalidProductIdentifiers);
    
#warning 在这儿把服务器的数据返回给前端，产品列表接口
}

-(void)purchaseProductID:(NSString *)productIdentifier verifyURL:(NSString *)verifyURL quantity:(NSInteger)quantity {
    SKProduct *product = self.productsDic[productIdentifier];
    self.verifyURL = verifyURL;
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    if (product) {
        dic[@"status"] = @0;
        dic[@"msg"] = @"purchase start";
        [self callBackJsonWithFunction:@"onPurchaseState" parameter:dic];
        //创建产品支付对象
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = quantity;
        //支付队列，将支付对象加入支付队列就形成一次购买请求
//        if (![SKPaymentQueue canMakePayments]){
//            NSLog(@"用户禁止应用内付费购买");
//            NSString *str = @"用户禁止应用内付费购买";
//            NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onSettingState('%@');",str];
//            [EUtility brwView:self.meBrwView evaluateScript:jsString];
//            return;
//        }
        [[SKPaymentQueue defaultQueue] addTransactionObserver:[uexIAPManager sharedInstance]];
        //添加到支付队列，开始请求支付
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }else{
        dic[@"status"] = @1;
        dic[@"msg"] = @"product is nil";
        [self callBackJsonWithFunction:@"onPurchaseState" parameter:dic];
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
            //      NSLog(@"交易\"%@\"成功.",paymentTransaction.payment.productIdentifier);
//            self.dic[@"productIdentifier"]= paymentTransaction.payment.productIdentifier ;
//            self.dic[@"quantity"] = [NSString stringWithFormat:@"%ld",(long)paymentTransaction.payment.quantity];
//            self.dic[@"transactionDate"] = [NSString stringWithFormat:@"%@",paymentTransaction.transactionDate];
//            self.dic[@"transactionIdentifier"] = paymentTransaction.transactionIdentifier;
//            self.dic[@"transactionState"] = @"购买成功";
//            if (self.isShow) {
//                NSString *jsonStr = [self.dic JSONFragment];
//                NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onTransactionState('%@');",jsonStr];
//                [EUtility brwView:self.meBrwView evaluateScript:jsString];
//            }
            
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
            dic[@"status"] = @1;//@"恢复成功";
            [self callBackJsonWithFunction:@"onTransactionState" parameter:dic];
            //结束支付交易
            [[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
            
        }else if(paymentTransaction.transactionState==SKPaymentTransactionStateFailed){
            dic[@"status"] = @2;// @"购买失败";
            dic[@"errorCode"] = @(paymentTransaction.error.code);
            dic[@"errorDescription"] = paymentTransaction.error.localizedDescription;
            dic[@"productIdentifier"]= paymentTransaction.payment.productIdentifier ;
            [self callBackJsonWithFunction:@"onTransactionState" parameter:dic];
            [[SKPaymentQueue defaultQueue] finishTransaction:paymentTransaction];
        }
        
    }];
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:[uexIAPManager sharedInstance]];
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
    NSError *error = nil;
    NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    NSData *responseData=[NSURLConnection sendSynchronousRequest:requestM returningResponse:nil error:&error];
    if (error) {
        dic[@"status"] = @3;//@"验证购买过程中发生错误"
        dic[@"errorCode"] = @(error.code);
        dic[@"errorDescription"] = error.localizedDescription;
    }else if (responseData == nil){
        dic[@"status"] = @4;//@"验证购买过程中返回数据为空"
        dic[@"msg"] = @"responseData is nil";
    }else{
       dic = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
    }
    [self callBackJsonWithFunction:@"onTransactionState" parameter:dic];
 
    /*------------*/
    //    NSURLSession *session = [NSURLSession sharedSession];
//        NSURLSessionDataTask *task = [session dataTaskWithRequest:requestM completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
//    
//        }];
    //    NSURLSessionDataTask *task = [session dataTaskWithURL:[NSURL URLWithString:bodyString] completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    //        /*data参数就是从网络上下载下来的数据
    //         这个数据是服务器把 字典/数组 根据JSON协议编码以后生成的. 拿到JSON数据以后, 我们要反编码 回到字典或者数组
    //         */
    //        //因为根据返回值类型, 可以看到是字典类型的
    //        //Serialization:序列化
    //        //参数2:options 代表当前data原始数据是什么类型
    //        //MutableContainers:代表原始数据是数组/字典
    //        NSError *err = nil;
    //        NSDictionary *responseObj = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&err];
    //
    //
    //
    //    }];
    //开始发送请求
    // [task resume];
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
    [self callBackJsonWithFunction:@"onRestoreState" parameter:dic];
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
     NSMutableDictionary *dic = [NSMutableDictionary dictionary];
    if (error) {
        dic[@"status"] = @1;//恢复购买失败
        dic[@"errorCode"] = @(error.code);
        dic[@"errorDescription"] = error.localizedDescription;
        [self callBackJsonWithFunction:@"onRestoreState" parameter:dic];
    }
}

#pragma mark - CallBack Method
const static NSString *kPluginName=@"uexInAppPurchase";
-(void)callBackJsonWithFunction:(NSString *)functionName parameter:(id)obj{
    NSString *jsonStr = [NSString stringWithFormat:@"if(%@.%@ != null){%@.%@('%@');}",kPluginName,functionName,kPluginName,functionName,[obj JSONFragment]];
    [EUtility brwView:self.meBrwView evaluateScript:jsonStr];
    
}
@end
