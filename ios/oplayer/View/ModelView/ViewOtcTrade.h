//
//  ViewOtcTrade.h
//  ViewOtcTrade
//
//  OTC下单时模态输入框

#import "ViewFullScreenBase.h"
#import "WsPromise.h"

@interface ViewOtcTrade : ViewFullScreenBase<UITextFieldDelegate>

- (instancetype)initWithAdInfo:(id)ad_info lock_info:(id)lock_info result_promise:(WsPromiseObject*)result_promise;

@end
