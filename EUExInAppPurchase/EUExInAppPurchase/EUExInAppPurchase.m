//
//  EUExInAppPurchase.m

//
//  Created by 杨广 on 16/1/9.
//  Copyright © 2016年 杨广. All rights reserved.
//

#import "EUExInAppPurchase.h"
#import "JSON.h"
#import "EUtility.h"
//#define kAppStoreVerifyURL @"https://buy.itunes.apple.com/verifyReceipt" //实际购买验证URL
//#define kSandboxVerifyURL @"https://sandbox.itunes.apple.com/verifyReceipt" //开发阶段沙盒验证URL


//定义可以购买的产品ID，必须和iTunes Connect中设置的一致
//#define kProductID1 @"ProtectiveGloves" //强力手套，非消耗品
//#define kProductID2 @"GoldenGlobe" //金球，非消耗品
//#define kProductID3 @"EnergyBottle" //能量瓶，消耗品

@implementation EUExInAppPurchase
-(id)initWithBrwView:(EBrowserView *) eInBrwView {
    if (self = [super initWithBrwView:eInBrwView]) {
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
        
    }
    return self;
}
-(void)getProductList:(NSMutableArray *)inArguments {
    NSLog(@"-----------------");
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
   // NSSet *sets=[NSSet setWithObjects:kProductID1,kProductID2,kProductID3, nil];
    //定义请求用于获取产品
    SKProductsRequest *productRequest=[[SKProductsRequest alloc]initWithProductIdentifiers:sets];
    //设置代理,用于获取产品加载状态
    productRequest.delegate=self;
    //开始请求
    [productRequest start];
    
    
}

#pragma mark - SKProductsRequestd代理方法
-(void)requestDidFinish:(SKRequest *)request{
    NSLog(@"请求完成.");
    NSString *requestStr = @"请求完成";
    //返回请求状态
    NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onRequestState('%@');",requestStr];
    [EUtility brwView:meBrwView evaluateScript:jsString];
}
-(void)request:(SKRequest *)request didFailWithError:(NSError *)error{
    NSLog(@"请求过程中发生错误，错误信息：%@",error.localizedDescription);
    NSString *requestStr = [NSString stringWithFormat:@"%@",error.localizedDescription];
    //返回请求状态
    NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onRequestState('%@');",requestStr];
    [EUtility brwView:meBrwView evaluateScript:jsString];
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
    [response.products enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        SKProduct *product=obj;
//                 NSLog(@"%@",product.localizedDescription);
//                 NSLog(@"%@",product.localizedTitle);
//                 NSLog(@"%@",product.price);
//                 NSLog(@"%@",product.productIdentifier);
        NSString *price = [NSString stringWithFormat:@"%@",product.price];
        NSDictionary *dic = @{@"productIdentifier":product.productIdentifier,@"localizedTitle":product.localizedTitle,@"price":price,@"localizedDescription":product.localizedDescription};
        [self.productsDic setObject:product forKey:product.productIdentifier];
        [procuctsArr addObject:dic];
            }];
    NSString *jsonStr = nil;
    if (procuctsArr.count > 0) {
       jsonStr = [procuctsArr JSONFragment];
    }
    //返回产品数据给前端
    NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.cbGetProductList('%@');",jsonStr];
    [EUtility brwView:meBrwView evaluateScript:jsString];

#warning 在这儿把服务器的数据返回给前端，产品列表接口
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
    BOOL appStoreVerifyUR = [[jsonDict objectForKey:@"appStoreVerifyURL"] boolValue];
    self.verifyURL = appStoreVerifyUR? @"https://buy.itunes.apple.com/verifyReceipt":@"https://sandbox.itunes.apple.com/verifyReceipt";
    SKProduct *product=self.productsDic[productIdentifier];
    //NSString *str = nil;
    if (product) {
        NSString *str = @"开始购买";
        NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onPurchaseState('%@');",str];
        [EUtility brwView:meBrwView evaluateScript:jsString];
        [self purchaseProduct:product];
    }else{
        NSLog(@"没有可购买的商品");
        NSString *str = @"没有可购买的商品";
        NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onPurchaseState('%@');",str];
        [EUtility brwView:meBrwView evaluateScript:jsString];
    }
    
   
    
    }

-(void)purchaseProduct:(SKProduct *)product{
        //创建产品支付对象
        SKPayment *payment=[SKPayment paymentWithProduct:product];
        //支付队列，将支付对象加入支付队列就形成一次购买请求
        if (![SKPaymentQueue canMakePayments]) {
            NSLog(@"用户禁止应用内付费购买");
            NSString *str = @"用户禁止应用内付费购买";
            NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onSettingState('%@');",str];
            [EUtility brwView:meBrwView evaluateScript:jsString];
            return;
        }
        SKPaymentQueue *paymentQueue=[SKPaymentQueue defaultQueue];
        //添加都支付队列，开始请求支付
    
        [paymentQueue addPayment:payment];
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
       
       if (paymentTransaction.transactionState ==SKPaymentTransactionStatePurchased){//已购买成功
//            NSLog(@"交易\"%@\"成功.",paymentTransaction.payment.productIdentifier);
           dic[@"productIdentifier"]= paymentTransaction.payment.productIdentifier ;
           dic[@"quantity"] = [NSString stringWithFormat:@"%ld",(long)paymentTransaction.payment.quantity];
           //dic[@"transactionState"]  =
           dic[@"transactionDate"] = [NSString stringWithFormat:@"%@",paymentTransaction.transactionDate];
           dic[@"transactionIdentifier"] = paymentTransaction.transactionIdentifier;
           dic[@"transactionState"] = @"购买成功";
            //购买成功后进行验证
            [self verifyPurchaseWithPaymentTransaction];
            //结束支付交易
           [queue finishTransaction:paymentTransaction];
       }else if(paymentTransaction.transactionState==SKPaymentTransactionStateRestored){//恢复成功，对于非消耗品才能恢复,如果恢复成功则transaction中记录的恢复的产品交易
//            NSLog(@"恢复交易\"%@\"成功.",paymentTransaction.payment.productIdentifier);
           dic[@"transactionDate"] = [NSString stringWithFormat:@"%@",paymentTransaction.transactionDate];
           dic[@"transactionIdentifier"] = paymentTransaction.transactionIdentifier;
           dic[@"originalTransaction"] = @{@"productIdentifier":paymentTransaction.originalTransaction.payment.productIdentifier,@"quantity":[NSString stringWithFormat:@"%ld",(long)paymentTransaction.originalTransaction.payment.quantity],@"transactionDate":[NSString stringWithFormat:@"%@",paymentTransaction.originalTransaction.transactionDate]};
           dic[@"productIdentifier"]= paymentTransaction.payment.productIdentifier ;
           dic[@"quantity"] = [NSString stringWithFormat:@"%ld",(long)paymentTransaction.payment.quantity];
            dic[@"transactionState"] = @"恢复成功";
           [queue finishTransaction:paymentTransaction];//结束支付交易
           
        }else if(paymentTransaction.transactionState==SKPaymentTransactionStateFailed){
          
            //dic[@"quantity"] = [NSString stringWithFormat:@"%ld",(long)paymentTransaction.payment.quantity];
            NSString *errorStr = nil;
            if (paymentTransaction.error.code==SKErrorPaymentCancelled) {
                errorStr = @"用户取消购买";
            }else{
                errorStr = [NSString stringWithFormat:@"%ld",paymentTransaction.error.code];
            }
            dic[@"error"] = errorStr;
            dic[@"productIdentifier"]= paymentTransaction.payment.productIdentifier ;
            dic[@"transactionState"] = @"购买失败";
        }
        
    }];
    NSString *jsonStr = [dic JSONFragment];
    NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onTransactionState('%@');",jsonStr];
    [EUtility brwView:meBrwView evaluateScript:jsString];
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
    NSError *error=nil;
    NSData *responseData=[NSURLConnection sendSynchronousRequest:requestM returningResponse:nil error:&error];
    if (error) {
        NSLog(@"验证购买过程中发生错误，错误信息：%@",error.localizedDescription);
        NSString *str = [NSString stringWithFormat:@"验证购买过程中发生错误，错误信息：%@",error.localizedDescription];
        NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onVerifyState('%@');",str];
        [EUtility brwView:meBrwView evaluateScript:jsString];
        return;
    }
    NSString *jsonStr = [[NSString alloc]initWithData:responseData encoding:NSUTF8StringEncoding];
    NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.cbGetVerifyInfo('%@');",jsonStr];
    [EUtility brwView:meBrwView evaluateScript:jsString];
   
    
}
//**********************************************************************
-(void)restorePurchase:(NSMutableArray *)inArguments{
    SKPaymentQueue *paymentQueue=[SKPaymentQueue defaultQueue];
    //恢复所有非消耗品
    [paymentQueue restoreCompletedTransactions];
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSString *str = nil;
    if (error) {
        NSLog(@"恢复失败:%@",error);
    str = [NSString stringWithFormat:@"恢复失败:%@",error];
    }
    NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onRestoreState('%@');",str];
    [EUtility brwView:meBrwView evaluateScript:jsString];
}
//恢复购买完成
-(void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue{
    NSLog(@"恢复完成");
    NSString *str = @"恢复完成";
    NSString *jsString = [NSString stringWithFormat:@"uexInAppPurchase.onRestoreState('%@');",str];
    [EUtility brwView:meBrwView evaluateScript:jsString];
}
-(void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}
@end
